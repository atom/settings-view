_ = require 'underscore-plus'
{remote} = require 'electron'
path = require 'path'
fs = require 'fs-plus'
CachedAssets = require '../lib/cached-assets'

describe "CachedAssets", ->
  [cachedAssets, assetPath, expectedPath] = []
  url = 'https://avatars.githubusercontent.com/atom'
  hash = 'ef922d415c3f7f10020c82bb509986cb'

  beforeEach ->
    spyOn(CachedAssets.prototype, 'getCachePath').andCallFake ->
      path.join(remote.app.getPath('userData'), 'Cache', 'Specs', 'asset-cache')
    cachedAssets = new CachedAssets()

    waitsForPromise ->
      cachedAssets.createAssetCache()

  afterEach ->
    [cachedAssets, assetPath, expectedPath] = []

  it "accepts an expiry option", ->
    runs ->
      cachedAssets = new CachedAssets({expiry: 10})
      expect(cachedAssets.options.expiry).toBe(10)

  describe "::asset", ->
    beforeEach ->
      spyOn(cachedAssets, 'cache').andCallFake (url) ->
        hash = cachedAssets.hashForUrl(url)
        assetPath = cachedAssets.assetPath hash

        Promise.resolve(assetPath)

    it "takes an url and returns a path calling ::cache", ->
      cachedAssets.assets = {}

      waitsForPromise ->
        cachedAssets.asset(url)

      runs ->
        expect(cachedAssets.cache).toHaveBeenCalled()

    it "returns the entry from @assets if found", ->
      cachedAssets.assets = {
        'ef922d415c3f7f10020c82bb509986cb': '/cached/path'
      }

      waitsForPromise ->
        cachedAssets.asset(url)
          .then (cachedPath) ->
            assetPath = cachedPath

      runs ->
        expect(cachedAssets.cache).not.toHaveBeenCalled()
        expect(assetPath).toBe('/cached/path')


  describe "::cache", ->
    it "takes an url and returns the path to the cached asset", ->
      runs ->
        spyOn(Date, 'now').andReturn(100)
        spyOn(fs, 'createWriteStream').andCallThrough()

        cachedAssets = new CachedAssets()
        expectedPath = cachedAssets.assetPath(cachedAssets.hashForUrl(url))

      waitsForPromise ->
        cachedAssets.cache(url)
          .then (cachedPath) ->
            assetPath = cachedPath

      runs ->
        expect(fs.createWriteStream).toHaveBeenCalled()
        expect(assetPath).toBe(expectedPath)

  describe "::assetPath", ->
    it "returns the path to an cached asset with the hash", ->
      spyOn(Date, 'now').andReturn(100)
      cachedAssets = new CachedAssets()
      expectedPath = path.join cachedAssets.getCachePath(), "#{hash}-#{Date.now()}"

      expect(cachedAssets.assetPath(hash)).toBe(expectedPath)

  describe "::hashForUrl", ->
    it "returns a md5 hash for an url", ->
      expect(cachedAssets.hashForUrl(url)).toBe('ef922d415c3f7f10020c82bb509986cb')

  describe "::getCachePath", ->
    it "returns the path to the cache directory", ->
      jasmine.unspy(CachedAssets.prototype, 'getCachePath')
      expect(cachedAssets.getCachePath()).toBe(path.join(remote.app.getPath('userData'), 'Cache', 'asset-cache'))

  describe "::createAssetCache", ->
    [cachePath] = []

    beforeEach ->
      spyOn(fs, 'makeTreeSync').andCallThrough()
      spyOn(fs, 'lstatSync').andCallThrough()

      cachedAssets = new CachedAssets()

    it "creates a directory if it does not exist", ->
      runs ->
        fs.removeSync cachedAssets.getCachePath()

      waitsForPromise ->
        cachedAssets.createAssetCache()
          .then (dir) ->
            cachePath = dir

      runs ->
        expect(fs.makeTreeSync).toHaveBeenCalled()
        expect(cachePath).toBe(cachedAssets.getCachePath())

    it "does not create a directory if it is already created", ->
      waitsForPromise ->
        cachedAssets.createAssetCache()

      waitsForPromise ->
        cachedAssets.createAssetCache()
          .then (dir) ->
            cachePath = dir

      runs ->
        expect(fs.makeTreeSync).not.toHaveBeenCalled()
        expect(cachePath).toBe(cachedAssets.getCachePath())

  describe "::expireAssetCache", ->
    [cachedAsset, expectedPath] = []

    beforeEach ->
      spyOn(fs, 'removeSync').andCallThrough()

      waitsForPromise ->
        cachedAssets.cache url
          .then (assetPath) ->
            cachedAsset = assetPath

    it "removes old assets", ->
      cachedAssets.expiry = cachedAssets.expiry * -1
      expect(fs.isFileSync(cachedAsset)).toBe(true)

      waitsForPromise ->
        cachedAssets.expireAssetCache()

      runs ->
        expect(fs.isFileSync(cachedAsset)).toBe(false)
        expect(fs.removeSync).toHaveBeenCalled()

    it "leaves fresh assets", ->
      expect(fs.isFileSync(cachedAsset)).toBe(true)

      waitsForPromise ->
        cachedAssets.expireAssetCache()

      runs ->
        expect(fs.isFileSync(cachedAsset)).toBe(true)
        expect(fs.removeSync).not.toHaveBeenCalled()

  describe "::loadCachedAssets", ->
    it "adds cached files to @assets", ->
      waitsForPromise ->
        cachedAssets.cache(url)
        cachedAssets.cache(url + '?otherversion=true')

      waitsForPromise ->
        cachedAssets.assets = {}
        cachedAssets.loadCachedAssets()

      runs ->
        expect(_.keys(cachedAssets.assets).length).toBe(2)
