PackageManager = require '../lib/package-manager'

describe "package manager", ->
  it "handle errors spawning apm", ->
    spyOn(atom.packages, 'getApmPath').andReturn('/an/invalid/apm/command/to/run')
    packageManager = new PackageManager()

    waitsForPromise shouldReject: true, -> packageManager.search('test')
    waitsForPromise shouldReject: true, -> packageManager.getInstalled()
    waitsForPromise shouldReject: true, -> packageManager.getOutdated()
    waitsForPromise shouldReject: true, -> packageManager.getFeatured()

    installCallback = jasmine.createSpy('installCallback')
    uninstallCallback = jasmine.createSpy('uninstallCallback')

    runs ->
      packageManager.install {name: 'foo', version: '1.0.0'}, installCallback

    waitsFor ->
      installCallback.callCount is 1

    runs ->
      expect(installCallback.argsForCall[0][0].message).toBe "Installing \u201Cfoo@1.0.0\u201D failed."
      expect(installCallback.argsForCall[0][0].packageInstallError).toBe true

    runs ->
      packageManager.uninstall {name: 'foo'}, uninstallCallback

    waitsFor ->
      uninstallCallback.callCount is 1

    runs ->
      expect(uninstallCallback.argsForCall[0][0].message).toBe "Uninstalling \u201Cfoo\u201D failed."
