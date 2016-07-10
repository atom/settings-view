path = require 'path'
process = require 'process'
PackageManager = require '../lib/package-manager'

describe "package manager", ->
  [packageManager] = []

  beforeEach ->
    spyOn(atom.packages, 'getApmPath').andReturn('/an/invalid/apm/command/to/run')
    packageManager = new PackageManager()

  describe "::jsonCommad", ->
    runArgs = []

    beforeEach ->
      spyOn(packageManager, 'command').andCallFake (args, errorMessage) ->
        runArgs = args
        new Promise (resolve, reject) ->
          resolve('{"foo":"bar"}')

    it "calls ::command with --json", ->
      packageManager.jsonCommand(['two', 'arguments'])
      expect(packageManager.command).toHaveBeenCalled()
      expect(runArgs).toEqual ['two', 'arguments', '--json']

  describe "::unload", ->
    beforeEach ->
      spyOn(atom.packages, 'deactivatePackage')
      spyOn(atom.packages, 'unloadPackage')

    it "deactivates and unloads a package when active and loaded", ->
      spyOn(atom.packages, 'isPackageActive').andReturn(true)
      spyOn(atom.packages, 'isPackageLoaded').andReturn(true)

      waitsForPromise ->
        packageManager.unload('package')

      runs ->
        expect(atom.packages.deactivatePackage.callCount).toBe(1)
        expect(atom.packages.unloadPackage.callCount).toBe(1)

    it "does not deactivate and unload a package when not active or loaded", ->
      spyOn(atom.packages, 'isPackageActive').andReturn(false)
      spyOn(atom.packages, 'isPackageLoaded').andReturn(false)

      waitsForPromise ->
        packageManager.unload('package')

      runs ->
        expect(atom.packages.deactivatePackage.callCount).toBe(0)
        expect(atom.packages.unloadPackage.callCount).toBe(0)

  it "handle errors spawning apm", ->
    noSuchCommandError = if process.platform is 'win32' then ' cannot find the path ' else 'ENOENT'
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
      installArg = installCallback.argsForCall[0][0]
      expect(installArg.message).toBe "Installing \u201Cfoo@1.0.0\u201D failed."
      expect(installArg.packageInstallError).toBe true
      expect(installArg.stderr).toContain noSuchCommandError

      packageManager.uninstall {name: 'foo'}, uninstallCallback

    waitsFor ->
      uninstallCallback.callCount is 1

    runs ->
      uninstallArg = uninstallCallback.argsForCall[0][0]
      expect(uninstallArg.message).toBe "Uninstalling \u201Cfoo\u201D failed."
      expect(uninstallArg.stderr).toContain noSuchCommandError

      packageManager.update {name: 'foo'}, '1.0.0', updateCallback

    waitsFor ->
      updateCallback.callCount is 1

    runs ->
      updateArg = updateCallback.argsForCall[0][0]
      expect(updateArg.message).toBe "Updating to \u201Cfoo@1.0.0\u201D failed."
      expect(updateArg.packageInstallError).toBe true
      expect(updateArg.stderr).toContain noSuchCommandError

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
      expect(runArgs).toEqual ['install', 'something', '--json']

    it "installs the package@version when a version is specified", ->
      packageManager.install {name: 'something', version: '0.2.3'}, ->
      expect(packageManager.runCommand).toHaveBeenCalled()
      expect(runArgs).toEqual ['install', 'something@0.2.3', '--json']

    it "installs the package and adds the package to the available package names", ->
      packageManager.cacheAvailablePackageNames(user: [{name: 'a-package'}])
      packageManager.install {name: 'something', version: '0.2.3'}, ->

      expect(packageManager.getAvailablePackageNames()).not.toContain('something')
      runCallback(0, '', '')
      expect(packageManager.getAvailablePackageNames()).toContain('something')

    describe "git url installation", ->
      it 'installs https:// urls', ->
        url = "https://github.com/user/repo.git"
        packageManager.install {name: url}
        expect(packageManager.runCommand).toHaveBeenCalled()
        expect(runArgs).toEqual ['install', 'https://github.com/user/repo.git', '--json']

      it 'installs git@ urls', ->
        url = "git@github.com:user/repo.git"
        packageManager.install {name: url}
        expect(packageManager.runCommand).toHaveBeenCalled()
        expect(runArgs).toEqual ['install', 'git@github.com:user/repo.git', '--json']

      it 'installs user/repo url shortcuts', ->
        url = "user/repo"
        packageManager.install {name: url}
        expect(packageManager.runCommand).toHaveBeenCalled()
        expect(runArgs).toEqual ['install', 'user/repo', '--json']

      it 'installs and activates git pacakges with names different from the repo name', ->
        spyOn(atom.packages, 'activatePackage')
        packageManager.install(name: 'git-repo-name')
        json =
          metadata:
            name: 'real-package-name'
        runCallback(0, JSON.stringify([json]), '')
        expect(atom.packages.activatePackage).toHaveBeenCalledWith json.metadata.name

      it 'emits an installed event with a copy of the pack including the full package metadata', ->
        spyOn(packageManager, 'emitPackageEvent')
        originalPackObject = name: 'git-repo-name', otherData: {will: 'beCopied'}
        packageManager.install(originalPackObject)
        json =
          metadata:
            name: 'real-package-name'
            moreInfo: 'yep'
        runCallback(0, JSON.stringify([json]), '')

        installEmittedCount = 0
        for call in packageManager.emitPackageEvent.calls
          if call.args[0] is "installed"
            expect(call.args[1]).not.toEqual originalPackObject
            expect(call.args[1].moreInfo).toEqual "yep"
            expect(call.args[1].otherData).toBe originalPackObject.otherData
            installEmittedCount++
        expect(installEmittedCount).toBe 1

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
      expect(packageManager.runCommand.calls[1].args[0]).toEqual(['install', 'a-new-package', '--json'])
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
