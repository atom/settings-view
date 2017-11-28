fs = require 'fs-plus'
path = require 'path'
{remote} = require 'electron'

glob = require 'glob'
request = require 'request'

module.exports =
class AtomIoClient
  constructor: (@packageManager, @baseURL) ->
    @baseURL ?= 'https://atom.io/api/'
    # 12 hour expiry
    @expiry = 1000 * 60 * 60 * 12
    @createAvatarCache()
    @expireAvatarCache()

  # Public: Get an avatar image from the filesystem, fetching it first if necessary
  avatar: (login, callback) ->
    @cachedAvatar login, (err, cached) =>
      stale = Date.now() - parseInt(cached.split('-').pop()) > @expiry if cached
      if cached and (not stale or not @online())
        callback null, cached
      else
        @fetchAndCacheAvatar(login, callback)

  # Public: get a package from the atom.io API, with the appropriate level of
  # caching.
  package: (name, callback) ->
    packagePath = "packages/#{name}"
    @fetchFromCache packagePath, {}, (err, data) =>
      if data
        callback(null, data)
      else
        @request(packagePath, callback)

  featuredPackages: (callback) ->
    # TODO clean up caching copypasta
    @fetchFromCache 'packages/featured', {}, (err, data) =>
      if data
        callback(null, data)
      else
        @getFeatured(false, callback)

  featuredThemes: (callback) ->
    # TODO clean up caching copypasta
    @fetchFromCache 'themes/featured', {}, (err, data) =>
      if data
        callback(null, data)
      else
        @getFeatured(true, callback)

  getFeatured: (loadThemes, callback) ->
    # apm already does this, might as well use it instead of request i guess? The
    # downside is that I need to repeat caching logic here.
    @packageManager.getFeatured(loadThemes)
      .then (packages) =>
        # copypasta from below
        key = if loadThemes then 'themes/featured' else 'packages/featured'
        cached =
          data: packages
          createdOn: Date.now()
        localStorage.setItem(@cacheKeyForPath(key), JSON.stringify(cached))
        # end copypasta
        callback(null, packages)
      .catch (error) ->
        callback(error, null)

  request: (path, callback) ->
    options = {
      url: "#{@baseURL}#{path}"
      headers: {'User-Agent': navigator.userAgent}
    }

    request options, (err, res, body) =>
      try
        data = JSON.parse(body)
      catch error
        return callback(error)

      delete data.versions
      cached =
        data: data
        createdOn: Date.now()
      localStorage.setItem(@cacheKeyForPath(path), JSON.stringify(cached))
      callback(err, cached.data)

  cacheKeyForPath: (path) ->
    "settings-view:#{path}"

  online: ->
    navigator.onLine

  # This could use a better name, since it checks whether it's appropriate to return
  # the cached data and pretends it's null if it's stale and we're online
  fetchFromCache: (packagePath, options, callback) ->
    unless callback
      callback = options
      options = {}

    unless options.force
      # Set `force` to true if we can't reach the network.
      options.force = not @online()

    cached = localStorage.getItem(@cacheKeyForPath(packagePath))
    cached = if cached then JSON.parse(cached)
    if cached? and (not @online() or options.force or (Date.now() - cached.createdOn < @expiry))
      cached ?= data: {}
      callback(null, cached.data)
    else if not cached? and not @online()
      # The user hasn't requested this resource before and there's no way for us
      # to get it to them so just hand back an empty object so callers don't crash
      callback(null, {})
    else
      # falsy data means "try to hit the network"
      callback(null, null)

  createAvatarCache: ->
    fs.makeTree(@getCachePath())

  avatarPath: (login) ->
    path.join @getCachePath(), "#{login}-#{Date.now()}"

  cachedAvatar: (login, callback) ->
    glob @avatarGlob(login), (err, files) =>
      return callback(err) if err
      files.sort().reverse()
      for imagePath in files
        filename = path.basename(imagePath)
        [..., createdOn] = filename.split('-')
        if Date.now() - parseInt(createdOn) < @expiry
          return callback(null, imagePath)
      callback(null, null)

  avatarGlob: (login) ->
    path.join @getCachePath(), "#{login}-*([0-9])"

  fetchAndCacheAvatar: (login, callback) ->
    if not @online()
      callback(null, null)
    else
      imagePath = @avatarPath login
      requestObject = {
        url: "https://avatars.githubusercontent.com/#{login}"
        headers: {'User-Agent': navigator.userAgent}
      }
      request.head requestObject, (error, response, body) ->
        if error? or response.statusCode isnt 200 or not response.headers['content-type'].startsWith('image/')
          callback(error)
        else
          writeStream = fs.createWriteStream imagePath
          writeStream.on 'finish', -> callback(null, imagePath)
          writeStream.on 'error', (error) ->
            writeStream.close()
            try
              fs.unlinkSync imagePath if fs.existsSync imagePath
            callback(error)
          request(requestObject).pipe(writeStream)

  # The cache expiry doesn't need to be clever, or even compare dates, it just
  # needs to always keep around the newest item, and that item only. The localStorage
  # cache updates in place, so it doesn't need to be purged.

  expireAvatarCache: ->
    deleteAvatar = (child) =>
      avatarPath = path.join(@getCachePath(), child)
      fs.unlink avatarPath, (error) ->
        if error and error.code isnt 'ENOENT' # Ignore cache paths that don't exist
          console.warn("Error deleting avatar (#{error.code}): #{avatarPath}")

    fs.readdir @getCachePath(), (error, _files) ->
      _files ?= []
      files = {}
      for filename in _files
        parts = filename.split('-')
        stamp = parts.pop()
        key = parts.join('-')
        files[key] ?= []
        files[key].push "#{key}-#{stamp}"

      for key, children of files
        children.sort()
        children.pop() # keep
        # Right now a bunch of clients might be instantiated at once, so
        # we can just ignore attempts to unlink files that have already been removed
        # - this should be fixed with a singleton client
        children.forEach(deleteAvatar)

  getCachePath: ->
    @cachePath ?= path.join(remote.app.getPath('userData'), 'Cache', 'settings-view')
