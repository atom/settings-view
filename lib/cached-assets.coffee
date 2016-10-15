_ = require 'underscore-plus'
request = require 'request'
crypto = require 'crypto'
fs = require 'fs-plus'
path = require 'path'
{remote} = require 'electron'

DefaultRequestHeaders = {
  'User-Agent': navigator.userAgent
}

module.exports =
class CachedAssets
  assets: {}
  #
  # Provides an interface to cache assets from remote locations on disk
  #
  constructor: (@options = {}) ->
    # 12 hour expiry
    @expiry = @options.expiry ? 1000 * 60 * 60 * 12

    @createAssetCache()
      .then => @expireAssetCache()
      .then => @loadCachedAssets()

  # Public: Takes a url and returns a Promise resolving with the assetPath on disk
  # If the asset is not yet cached it will go ahead and cache it on disk
  #
  # * `url` {String} to look up in the cache or request
  #
  # Returns a {Promise} resolving with the path of the asset on disk
  asset: (url) ->
    hash = @hashForUrl(url)
    if assetPath = @assets[hash]
      Promise.resolve(assetPath)
    else
      @assets[hash] ?= @cache(url)

  # Public: Caches an asset on disk
  #
  # * `url` {String} to be requested and cached
  #
  # Returns a {Promise} resolving with the path of the asset on disk
  cache: (url) ->
    new Promise (resolve, reject) =>
      hash = @hashForUrl(url)
      assetPath = @assetPath hash
      writeStream = fs.createWriteStream assetPath
      writeStream.on 'finish', =>
        @assets[hash] = assetPath
        resolve(assetPath)
      writeStream.on 'error', (error) -> reject(error)

      readStream = request({
        url: url
        headers: DefaultRequestHeaders
      })
      readStream.on 'error', (error) ->
        fs.unlinkSync assetPath
        reject(error)
      readStream.pipe(writeStream)

  assetPath: (hash) ->
    path.join @getCachePath(), "#{hash}-#{Date.now()}"

  hashForUrl: (url) ->
    crypto.createHash('md5').update(url).digest("hex") if url

  getCachePath: ->
    @cachePath ?= path.join(remote.app.getPath('userData'), 'Cache', 'asset-cache')

  createAssetCache: ->
    new Promise (resolve, reject) =>
      try
        cacheDir = fs.lstatSync(@getCachePath())
      catch

      unless cacheDir and cacheDir.isDirectory()
        fs.makeTreeSync @getCachePath()

      resolve(@getCachePath())

  expireAssetCache: ->
    new Promise (resolve, reject) =>
      fs.readdir @getCachePath(), (error, files) =>
        reject(error) if error

        files ?= []
        files.forEach (filename, idx) =>
          return unless filename
          [hash, createdOn] = filename.split('-')

          if parseInt(createdOn) > (Date.now() + @expiry)
            assetPath = path.join(@getCachePath(), filename)
            delete(@assets[hash])
            fs.removeSync assetPath

          resolve() if idx + 1 >= files.length


  loadCachedAssets: ->
    new Promise (resolve, reject) =>
      fs.readdir @getCachePath(), (error, files) =>
        reject(error) if error
        files = _.flatten [files]

        files ?= []
        files.forEach (filename, idx) =>
          return unless filename
          [hash, ...] = filename.split('-')
          @assets[hash] = path.join(@getCachePath(), filename)
          resolve() if idx + 1 >= files.length
