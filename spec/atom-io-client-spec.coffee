AtomIoClient = require '../lib/atom-io-client'

describe "AtomIoClient", ->

  beforeEach ->
    @client = new AtomIoClient

  it "fetches avatar from cache if the network is unavailable", ->
    spyOn(@client, 'online').andReturn(false)
    spyOn(@client, 'fetchAndCacheAvatar')
    expect(@client.fetchAndCacheAvatar).not.toHaveBeenCalled()
    @client.avatar 'test-user', ->

  it "fetches api json from cache if the network is unavailable", ->
    spyOn(@client, 'online').andReturn(false)
    spyOn(@client, 'fetchFromCache').andCallFake (path, opts, cb) ->
      cb(null, {})
    spyOn(@client, 'request')
    @client.package 'test-package', ->

    expect(@client.fetchFromCache).toHaveBeenCalled()
    expect(@client.request).not.toHaveBeenCalled()

  it "handles glob errors", ->
    spyOn(@client, 'avatarGlob').andReturn "#{__dirname}/**"
    spyOn(require('fs'), 'readdir').andCallFake (dirPath, callback) ->
      process.nextTick -> callback(new Error('readdir error'))

    callback = jasmine.createSpy('cacheAvatar callback')
    @client.cachedAvatar 'fakeperson', callback

    waitsFor ->
      callback.callCount is 1

    runs ->
      expect(callback.argsForCall[0][0].message).toBe 'readdir error'

  xit "purges old items from cache correctly"
    # "correctly" in this case means "remove all old items but one" so that we
    # always have stale data to return if the network is gone.
