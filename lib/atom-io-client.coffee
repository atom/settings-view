fs = require 'fs-plus'
path = require 'path'

app = require('remote').require('app')
glob = require 'glob'
request = require 'request'

module.exports =
class AtomIoClient
  constructor: (@baseURL) ->
    # 12 hour expiry
    @expiry = 1000 * 60 * 60 * 12
    @createAvatarCache()

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
        # TODO don't check expiry if network connection is not avail
        if Date.now() - parseInt(createdOn) < @expiry
          callback(null, imagePath)
          break

  avatar: (login, callback) ->
    @cachedAvatar login, (err, cached) =>
      if cached
        callback null, cached
      else
        @fetchAndCacheAvatar(login, callback)

  avatarGlob: (login) ->
    path.join app.getDataPath(), 'Cache/settings-view', "#{login}-*"

  fetchAndCacheAvatar: (login, callback) ->
    # TODO clean up cache
    imagePath = @avatarPath login
    stream = fs.createWriteStream imagePath
    stream.on 'finish', () -> callback(null, imagePath)
    request("https://github.com/#{login}.png").pipe(stream)
