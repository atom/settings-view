path = require 'path'
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

  describe "::isPackageInstalled()", ->
    it "returns false a package is not installed", ->
      expect(packageManager.isPackageInstalled('some-package')).toBe false

    it "returns true when a package is loaded", ->
      spyOn(atom.packages, 'isPackageLoaded').andReturn true
      expect(packageManager.isPackageInstalled('some-package')).toBe true

    it "returns true when a package is disabled", ->
      spyOn(atom.packages, 'isPackageDisabled').andReturn true
      expect(packageManager.isPackageInstalled('some-package')).toBe false

    it "returns true when a package is in the availablePackageCache", ->
      spyOn(packageManager, 'getAvailablePackageNames').andReturn ['some-package']
      expect(packageManager.isPackageInstalled('some-package')).toBe true

  describe "::install()", ->
    [runArgs, runCallback] = []

    beforeEach ->
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        runArgs = args
        runCallback = callback
        onWillThrowError: ->

    it "installs the latest version when a package version is not specified", ->
      packageManager.install {name: 'something'}, ->
      expect(packageManager.runCommand).toHaveBeenCalled()
      expect(runArgs).toEqual ['install', 'something']

    it "installs the package@version when a version is specified", ->
      packageManager.install {name: 'something', version: '0.2.3'}, ->
      expect(packageManager.runCommand).toHaveBeenCalled()
      expect(runArgs).toEqual ['install', 'something@0.2.3']

    it "installs the package and adds the package to the available package names", ->
      packageManager.cacheAvailablePackageNames(user: [{name: 'a-package'}])
      packageManager.install {name: 'something', version: '0.2.3'}, ->

      expect(packageManager.getAvailablePackageNames()).not.toContain('something')
      runCallback(0, '', '')
      expect(packageManager.getAvailablePackageNames()).toContain('something')

  describe "::uninstall()", ->
    [runArgs, runCallback] = []

    beforeEach ->
      spyOn(packageManager, 'unload')
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        runArgs = args
        runCallback = callback
        onWillThrowError: ->

    it "uninstalls the package and removes the package from the available package names", ->
      packageManager.cacheAvailablePackageNames(user: [{name: 'something'}])
      packageManager.uninstall {name: 'something'}, ->

      expect(packageManager.getAvailablePackageNames()).toContain('something')
      runCallback(0, '', '')
      expect(packageManager.getAvailablePackageNames()).not.toContain('something')

    it "removes the package from the core.disabledPackages list", ->
      atom.config.set('core.disabledPackages', ['something'])

      packageManager.cacheAvailablePackageNames(user: [{name: 'something'}])
      packageManager.uninstall {name: 'something'}, ->

      expect(atom.config.get('core.disabledPackages')).toContain('something')
      runCallback(0, '', '')
      expect(atom.config.get('core.disabledPackages')).not.toContain('something')

  describe "::installAlternative", ->
    beforeEach ->
      spyOn(atom.packages, 'activatePackage')
      spyOn(packageManager, 'runCommand').andCallFake ->
        onWillThrowError: ->
      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'language-test'))
      waitsFor ->
        atom.packages.isPackageLoaded('language-test') is true

    it "installs the latest version when a package version is not specified", ->
      installedCallback = jasmine.createSpy()
      installingEvent = jasmine.createSpy()
      installedEvent = jasmine.createSpy()

      eventArg =
        alternative: 'a-new-package'
        pack:
          name: 'language-test'

      packageManager.on 'package-installing-alternative', installingEvent
      packageManager.on 'package-installed-alternative', installedEvent

      packageManager.installAlternative({name: 'language-test'}, 'a-new-package', installedCallback)
      expect(packageManager.runCommand).toHaveBeenCalled()
      expect(packageManager.runCommand.calls[0].args[0]).toEqual(['uninstall', '--hard', 'language-test'])
      expect(packageManager.runCommand.calls[1].args[0]).toEqual(['install', 'a-new-package'])
      expect(atom.packages.isPackageLoaded('language-test')).toBe true

      expect(installedEvent).not.toHaveBeenCalled()
      expect(installingEvent).toHaveBeenCalled()
      expect(installingEvent.mostRecentCall.args[0]).toEqual eventArg

      packageManager.runCommand.calls[0].args[1](0, '', '')

      waits 1
      runs ->
        expect(atom.packages.activatePackage).not.toHaveBeenCalled()
        expect(atom.packages.isPackageLoaded('language-test')).toBe false

        packageManager.runCommand.calls[1].args[1](0, '', '')

      waits 1
      runs ->
        expect(atom.packages.activatePackage).toHaveBeenCalledWith 'a-new-package'
        expect(atom.packages.isPackageLoaded('language-test')).toBe false

        expect(installedEvent).toHaveBeenCalled()
        expect(installedEvent.mostRecentCall.args[0]).toEqual eventArg

        expect(installedCallback).toHaveBeenCalled()
        expect(installedCallback.mostRecentCall.args[0]).toEqual null
        expect(installedCallback.mostRecentCall.args[1]).toEqual eventArg

  describe "::packageHasSettings", ->
    it "returns true when the pacakge has config", ->
      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))
      expect(packageManager.packageHasSettings('package-with-config')).toBe true

    it "returns false when the pacakge does not have config and doesn't define language grammars", ->
      expect(packageManager.packageHasSettings('random-package')).toBe false

    it "returns true when the pacakge does not have config, but does define language grammars", ->
      packageName = 'language-test'

      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', packageName))

      runs ->
        expect(packageManager.packageHasSettings(packageName)).toBe true

  describe "::loadOutdated", ->
    it "caches results", ->
      [runArgs, runCallback] = []
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        callback(0, '["boop"]', '')
        onWillThrowError: ->

      packageManager.loadOutdated ->
      expect(packageManager.apmCache.loadOutdated.value).toMatch(['boop'])

      packageManager.loadOutdated ->
      expect(packageManager.runCommand.calls.length).toBe(1)


    it "expires results after a timeout", ->
      spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
        callback(0, '["boop"]', '')
        onWillThrowError: ->

      packageManager.loadOutdated ->
      now = Date.now()
      spyOn(Date, 'now').andReturn((-> now + packageManager.CACHE_EXPIRY + 1)())
      packageManager.loadOutdated ->

      expect(packageManager.runCommand.calls.length).toBe(2)

  it "expires results after a package updated/installed", ->
    packageManager.apmCache.loadOutdated =
      value: ['hi']
      expiry: Date.now() + 999999999

    [runArgs, runCallback] = []
    spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
      callback(0, '["boop"]', '')
      onWillThrowError: ->

    # Just prevent this stuff from calling through, it doesn't matter for this test
    spyOn(atom.packages, 'deactivatePackage').andReturn(true)
    spyOn(atom.packages, 'activatePackage').andReturn(true)
    spyOn(atom.packages, 'unloadPackage').andReturn(true)
    spyOn(atom.packages, 'loadPackage').andReturn(true)

    packageManager.loadOutdated ->
    expect(packageManager.runCommand.calls.length).toBe(0)

    packageManager.update {}, {}, -> # +1 runCommand call to update the package
    packageManager.loadOutdated -> # +1 runCommand call to load outdated because the cache should be wiped
    expect(packageManager.runCommand.calls.length).toBe(2)

    packageManager.install {}, -> # +1 runCommand call to install the package
    packageManager.loadOutdated -> # +1 runCommand call to load outdated because the cache should be wiped
    expect(packageManager.runCommand.calls.length).toBe(4)

    packageManager.loadOutdated -> # +0 runCommand call, should be cached
    expect(packageManager.runCommand.calls.length).toBe(4)
