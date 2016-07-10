Package = require '../lib/package'
PackageManager = require '../lib/package-manager'

describe "Package", ->
  [packageManager, pack] = []

  beforeEach ->
    packageManager = new PackageManager()
    pack = new Package('test-package', packageManager)

  describe "::unload", ->
    beforeEach ->
      spyOn(atom.packages, 'deactivatePackage')
      spyOn(atom.packages, 'unloadPackage')

    it "deactivates and unloads a package when active and loaded", ->
      spyOn(atom.packages, 'isPackageActive').andReturn(true)
      spyOn(atom.packages, 'isPackageLoaded').andReturn(true)

      runs ->
        pack.unload()
        expect(atom.packages.deactivatePackage.callCount).toBe(1)
        expect(atom.packages.unloadPackage.callCount).toBe(1)

    it "does not deactivate and unload a package when not active or loaded", ->
      spyOn(atom.packages, 'isPackageActive').andReturn(false)
      spyOn(atom.packages, 'isPackageLoaded').andReturn(false)

      runs ->
        pack.unload()
        expect(atom.packages.deactivatePackage.callCount).toBe(0)
        expect(atom.packages.unloadPackage.callCount).toBe(0)

  describe "::install", ->
    beforeEach ->
      spyOn(pack, 'enable').andReturn(true)
      spyOn(pack, 'unload').andCallFake ->
        new Promise (resolve, reject) ->
          resolve()

      spyOn(packageManager, 'install').andCallFake ->
        new Promise (resolve, reject) ->
          resolve()

    it "unloads the package", ->
      waitsForPromise ->
        pack.install()

      runs ->
        expect(pack.unload.callCount).toBe(1)

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
      spyOn(pack, 'unload').andCallFake ->
        new Promise (resolve, reject) ->
          resolve()

      spyOn(packageManager, 'update').andCallFake ->
        new Promise (resolve, reject) ->
          resolve()

    it "calls update on PackageManager", ->
      waitsForPromise ->
        pack.update()

      runs ->
        expect(packageManager.update.callCount).toBe(1)
