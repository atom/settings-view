PackageManager = require '../lib/package-manager'

describe "package manager", ->
  [packageManager] = []

  beforeEach ->
    spyOn(atom.packages, 'getApmPath').andReturn('/an/invalid/apm/command/to/run')
    packageManager = new PackageManager()

  it "handle errors spawning apm", ->
    waitsForPromise shouldReject: true, -> packageManager.search('test')
    waitsForPromise shouldReject: true, -> packageManager.getInstalled()
    waitsForPromise shouldReject: true, -> packageManager.getOutdated()
    waitsForPromise shouldReject: true, -> packageManager.getFeatured()
    waitsForPromise shouldReject: true, -> packageManager.getPackage('foo')

    installCallback = jasmine.createSpy('installCallback')
    uninstallCallback = jasmine.createSpy('uninstallCallback')
    updateCallback = jasmine.createSpy('updateCallback')

    runs ->
      packageManager.install {name: 'foo', version: '1.0.0'}, installCallback

    waitsFor ->
      installCallback.callCount is 1

    runs ->
      expect(installCallback.argsForCall[0][0].message).toBe "Installing \u201Cfoo@1.0.0\u201D failed."
      expect(installCallback.argsForCall[0][0].packageInstallError).toBe true
      expect(installCallback.argsForCall[0][0].stderr).toContain 'ENOENT'

      packageManager.uninstall {name: 'foo'}, uninstallCallback

    waitsFor ->
      uninstallCallback.callCount is 1

    runs ->
      expect(uninstallCallback.argsForCall[0][0].message).toBe "Uninstalling \u201Cfoo\u201D failed."
      expect(uninstallCallback.argsForCall[0][0].stderr).toContain 'ENOENT'

      packageManager.update {name: 'foo'}, '1.0.0', updateCallback

    waitsFor ->
      updateCallback.callCount is 1

    runs ->
      expect(updateCallback.argsForCall[0][0].message).toBe "Updating to \u201Cfoo@1.0.0\u201D failed."
      expect(updateCallback.argsForCall[0][0].packageInstallError).toBe true
      expect(updateCallback.argsForCall[0][0].stderr).toContain 'ENOENT'

  describe "installing", ->
    [runArgs, runCallback] = []

    beforeEach ->
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        runArgs = args
        runCallback = callback
        onWillThrowError: ->

    it "installs the latest version when a package version is not specified", ->
      packageManager.install {name:'something'}, ->
      expect(packageManager.runCommand).toHaveBeenCalled()
      expect(runArgs).toEqual ['install', 'something']
