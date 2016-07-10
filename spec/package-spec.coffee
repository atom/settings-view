Package = require '../lib/package'
PackageManager = require '../lib/package-manager'

describe "Package", ->
  [packageManager, pack] = []

  beforeEach ->
    packageManager = new PackageManager()
    pack = new Package('test-package', packageManager)

  describe "::install", ->
    beforeEach ->
      spyOn(pack, 'enable').andReturn(true)
      spyOn(packageManager, 'install').andCallFake ->
        new Promise (resolve, reject) ->
          resolve()

    it "calls install on PackageManager", ->
      waitsForPromise ->
        pack.install()

      runs ->
        expect(packageManager.install.callCount).toBe(1)

    it "enables the package when it is disabled", ->
      spyOn(pack, 'isDisabled').andReturn(true)

      waitsForPromise ->
        pack.install()

      runs ->
        expect(pack.enable.callCount).toBe(1)

    it "does not enable the package when it is is already", ->
      spyOn(pack, 'isDisabled').andReturn(false)

      waitsForPromise ->
        pack.install()

      runs ->
        expect(pack.enable.callCount).toBe(0)

  describe "::update", ->
    beforeEach ->
      spyOn(packageManager, 'update').andCallFake ->
        new Promise (resolve, reject) ->
          resolve()

    it "calls update on PackageManager", ->
      waitsForPromise ->
        pack.update()

      runs ->
        expect(packageManager.update.callCount).toBe(1)
