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
