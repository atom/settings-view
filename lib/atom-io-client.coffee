fs = require 'fs-plus'
path = require 'path'

app = require('remote').require('app')
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
    # apm already does this, might as well use it instead of request i guess?
    @packageManager.getFeatured(loadThemes)
      .then (packages) =>
        callback(null, packages)
      .catch (error) =>
        callback(error, null)

  request: (path, callback) ->
    request "#{@baseURL}#{path}", (err, res, body) =>
      data = JSON.parse(body)
      delete data['versions'] if data['versions']
      cached =
        data: data
        createdOn: Date.now()
      localStorage.setItem(@cacheKeyForPath(path), JSON.stringify(cached))
      callback(err, cached.data) # TODO handle parse error

  cacheKeyForPath: (path) ->
    "settings-view:#{path}"

  online: ->
    navigator.onLine

  fetchFromCache: (packagePath, options, callback) ->
    unless callback
      callback = options
      options = {}

    unless options.force
      # Set `force` to true if we can't reach the network.
      options.force = !@online()

    cached = localStorage.getItem(@cacheKeyForPath(packagePath))
    cached = if cached then JSON.parse(cached)
    # TODO - Needs to always return cached data when api is unreachable
    if cached? and (options.force or (Date.now() - cached.createdOn < @expiry))
      cached ?=  {data: {}}
      callback(null, cached.data)
    else
      callback(null, null)

  createAvatarCache: () ->
    cachePath = path.join(app.getDataPath(), 'Cache')
    fs.exists cachePath, (exists) ->
      fs.mkdirSync(cachePath) unless exists
      fs.exists path.join(cachePath, 'settings-view'), (exists) ->
        fs.mkdirSync(path.join(cachePath, 'settings-view')) unless exists

  avatarPath: (login) ->
    path.join app.getDataPath(), 'Cache/settings-view', "#{login}-#{Date.now()}"

  cachedAvatar: (login, callback) ->
    glob @avatarGlob(login), (err, files) =>
      files.sort().reverse()
      for imagePath in files
        filename = path.basename(imagePath)
        [..., createdOn] = filename.split('-')
        if Date.now() - parseInt(createdOn) < @expiry
          return callback(null, imagePath)
          break
      callback(null, null)

  avatarGlob: (login) ->
    path.join app.getDataPath(), 'Cache/settings-view', "#{login}-*"

  fetchAndCacheAvatar: (login, callback) ->
    imagePath = @avatarPath login
    stream = fs.createWriteStream imagePath
    stream.on 'finish', () -> callback(null, imagePath)
    # TODO stream.on error
    request("https://github.com/#{login}.png").pipe(stream)

  # The cache expiry doesn't need to be clever, or even compare dates, it just
  # needs to always keep around the newest item, and that item only. The localStorage
  # cache updates in place, so it doesn't need to be purged.

  expireAvatarCache: ->
    fs.readdir path.join(app.getDataPath(), 'Cache/settings-view'), (error, _files) ->
      files = {}
      for filename in _files
        parts = filename.split('-')
        stamp = parts.pop()
        key = parts.join('-')
        files[key] ?= []
        files[key].push "#{key}-#{stamp}"

      for key, children of files
        children.sort()
        keep = children.pop()
        (fs.unlink(path.join(app.getDataPath(), 'Cache/settings-view', child)) for child in children) # throw away callback
