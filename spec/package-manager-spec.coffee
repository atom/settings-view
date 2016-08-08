path = require 'path'
process = require 'process'
Package = require '../lib/package'
List = require '../lib/list'
PackageManager = require '../lib/package-manager'
{mockedPackageManager} = require './spec-helper'

describe "PackageManager", ->
  [packageManager] = []

  beforeEach ->
    packageManager = mockedPackageManager()

  describe "::asset", ->
    it "requests an asset from the asset cache", ->
      spyOn(packageManager.assetCache, 'asset').andReturn Promise.resolve()

      waitsFor ->
        packageManager.asset('http://url')

      runs ->
        expect(packageManager.assetCache.asset).toHaveBeenCalledWith('http://url')

  describe "::storeKeyForList", ->
    it "returns a combination of the storage key and the list name", ->
      listName = 'stored-list'
      expect(packageManager.storeKeyForList(listName))
        .toBe "#{packageManager.storageKey}:list:#{listName}"

  describe "::storeKeyForPackage", ->
    it "returns a combination of the storage key and the list name", ->
      packageName = 'stored-package'
      expect(packageManager.storeKeyForPackage(packageName))
        .toBe "#{packageManager.storageKey}:package:#{packageName}"

  describe "::storePackage", ->
    it "saves a Package to localStorage", ->
      spyOn(localStorage, "setItem").andCallThrough()
      pack = new Package {name: 'test-package'}, packageManager

      packageManager.storePackage(pack)

      expect(localStorage.setItem)
        .toHaveBeenCalledWith("#{packageManager.storageKey}:package:#{pack.name}", '{"name":"test-package"}')

  describe "::storedPackage", ->
    it "retrives a Package from localStorage", ->
      spyOn(localStorage, "getItem").andReturn('{"name":"test-package"}')

      storedPackage = packageManager.storedPackage('test-package')

      expect(localStorage.getItem)
        .toHaveBeenCalledWith("#{packageManager.storageKey}:package:test-package")
      expect(storedPackage.name).toBe('test-package')

  describe "::cachedPackage", ->
    [pack] = []

    beforeEach ->
      pack = new Package {name: 'test-package'}, packageManager

    it "puts an object into cachedPackages", ->
      expect(packageManager.cachedPackages[pack.name]).toBe undefined

      packageManager.cachedPackage(pack)
      expect(packageManager.cachedPackages[pack.name]).not.toBe undefined

    it "returns an object if already in the cache", ->
      packageManager.cachedPackages[pack.name] = pack
      expect(packageManager.cachedPackage(pack)).toBe pack

  describe "::storeList", ->
    it "saves a List to localStorage", ->
      spyOn(packageManager, "storePackage").andReturn(Promise.resolve())
      spyOn(localStorage, 'setItem').andCallThrough()
      list = ['package-name']

      waitsForPromise ->
        packageManager.storeList('stored-list', list)

      runs ->
        expect(localStorage.setItem)
          .toHaveBeenCalledWith('settings-view-specs:package-store:list:stored-list', '[null]')

  describe "::storedList", ->
    it "gets a list from localStorage", ->
      list = ['package-name']
      spyOn(packageManager, "storedPackage").andCallFake (name) ->
        {name: name}
      spyOn(localStorage, 'getItem').andCallFake (listName) ->
        JSON.stringify list

      packageManager.storedList('stored-list')

      expect(localStorage.getItem)
        .toHaveBeenCalledWith('settings-view-specs:package-store:list:stored-list')

  describe "::cachedList", ->
    [listName, packageArray] = []

    beforeEach ->
      listName = 'cached-list'
      packageArray = [new Package({name: 'test-package'})]

    it "puts creates a List from an Array and puts it into cachedLists", ->
      expect(packageManager.cachedLists[listName]).toBe undefined
      packageManager.cachedList(listName, packageArray)
      expect(packageManager.cachedLists[listName]).not.toBe undefined

    it "returns the List object if already set", ->
      list = new List 'name'
      list.setItems packageArray
      packageManager.cachedLists[listName] = list

      packageManager.cachedList(listName, [])
      expect(packageManager.cachedLists[listName]).toBe list

  describe "::jsonCommad", ->
    it "calls ::command with --json", ->
      waitsForPromise shouldReject: true, ->
        packageManager.jsonCommand(['two', 'arguments'])

      runs ->
        expect(packageManager.command)
          .toHaveBeenCalledWith(['two', 'arguments', '--json'], 'Running apm with --json failed')

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

    packageManager.search('test')
      .catch (error) ->
        expect(error.message).toBe "Searching for \u201Ctest\u201D failed."

    packageManager.getInstalled()
      .catch (error) ->
        expect(error.message).toBe "Fetching local packages failed."

    packageManager.getOutdated()
      .catch (error) ->
        expect(error.message).toBe "Fetching outdated packages and themes failed."

    packageManager.getFeatured()
      .catch (error) ->
        expect(error.message).toBe "Fetching featured packages failed."

    packageManager.getPackage('foo')
      .catch (error) ->
        expect(error.message).toBe "Fetching package 'foo' failed."

    packageManager.install({name: 'foo', version: '1.0.0'})
      .catch (error) ->
        expect(error.message).toBe "Installing \u201Cfoo@1.0.0\u201D failed."
        expect(error.packageInstallError).toBe true
        expect(error.stderr).toContain noSuchCommandError

    packageManager.uninstall({name: 'foo'})
      .catch (error) ->
        expect(error.message).toBe "Uninstalling \u201Cfoo\u201D failed."
        expect(error.stderr).toContain noSuchCommandError

    packageManager.update({name: 'foo'}, '1.0.0')
      .catch (error) ->
        expect(error.message).toBe "Updating to \u201Cfoo@1.0.0\u201D failed."
        expect(error.packageInstallError).toBe true
        expect(error.stderr).toContain noSuchCommandError

    packageManager.loadCompatiblePackageVersion('foo')
      .catch (error) ->
        expect(error.message).toBe "Fetching package 'foo' failed."

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
    it "installs the latest version when a package version is not specified", ->
      waitsForPromise ->
        packageManager.install {name: 'something'}

      runs ->
        expect(packageManager.command).toHaveBeenCalled()
        expect(runArgs).toEqual ['install', 'something', '--json']

    it "installs the package@version when a version is specified", ->
      waitsForPromise ->
        packageManager.install {name: 'something', version: '0.2.3'}

      runs ->
        expect(packageManager.command).toHaveBeenCalled()
        expect(runArgs).toEqual ['install', 'something@0.2.3', '--json']

    it "installs the package and adds the package to the available package names", ->
      packageManager.cacheAvailablePackageNames(user: [{name: 'a-package'}])

      runs ->
        expect(packageManager.getAvailablePackageNames()).not.toContain('something')

      waitsForPromise ->
        packageManager.install {name: 'something', version: '0.2.3'}

      runs ->
        expect(packageManager.getAvailablePackageNames()).toContain('something')

    it "installs and loads the package", ->
      spyOn(atom.packages, 'loadPackage').andReturn(true)

      waitsForPromise ->
        packageManager.install {name: 'something', version: '0.2.3'}

      runs ->
        expect(atom.packages.loadPackage).toHaveBeenCalledWith 'something'

    describe "git url installation", ->
      it 'installs https:// urls', ->
        url = "https://github.com/user/repo.git"

        waitsForPromise ->
          packageManager.install {name: url}

        runs ->
          expect(packageManager.command).toHaveBeenCalled()
          expect(runArgs).toEqual ['install', 'https://github.com/user/repo.git', '--json']

      it 'installs git@ urls', ->
        url = "git@github.com:user/repo.git"

        waitsForPromise ->
          packageManager.install {name: url}

        runs ->
          expect(packageManager.command).toHaveBeenCalled()
          expect(runArgs).toEqual ['install', 'git@github.com:user/repo.git', '--json']

      it 'installs user/repo url shortcuts', ->
        url = "user/repo"

        waitsForPromise ->
          packageManager.install {name: url}

        runs ->
          expect(packageManager.command).toHaveBeenCalled()
          expect(runArgs).toEqual ['install', 'user/repo', '--json']

      it 'installs and activates git pacakges with names different from the repo name', ->
        spyOn(atom.packages, 'activatePackage')

        jasmine.unspy(packageManager, 'command')
        spyOn(packageManager, 'command').andCallFake (args) ->
          new Promise (resolve, reject) ->
            jsonString = '{"metadata":{"name":"real-package-name"}}'
            resolve(jsonString)

        waitsForPromise ->
          packageManager.install(name: 'git-repo-name')

        runs ->
          expect(atom.packages.activatePackage).toHaveBeenCalledWith 'real-package-name'

      it 'emits an installed event with a copy of the pack including the full package metadata', ->
        originalPackObject = name: 'git-repo-name', otherData: {will: 'beCopied'}
        spyOn(packageManager, 'emitPackageEvent')

        jasmine.unspy(packageManager, 'command')
        spyOn(packageManager, 'command').andCallFake (args) ->
          new Promise (resolve, reject) ->
            runArgs = args
            json = '{"metadata":{"name":"real-package-name", "moreInfo":"yep"}}'
            resolve(json)

        waitsForPromise ->
          packageManager.install(originalPackObject)

        runs ->
          installEmittedCount = 0
          for call in packageManager.emitPackageEvent.calls
            if call.args[0] is "installed"
              expect(call.args[1]).not.toEqual originalPackObject
              expect(call.args[1].moreInfo).toEqual "yep"
              expect(call.args[1].otherData).toBe originalPackObject.otherData
              installEmittedCount++
          expect(installEmittedCount).toBe 1

  describe "::uninstall()", ->
    it "uninstalls the package and removes the package from the available package names", ->
      packageManager.cacheAvailablePackageNames(user: [{name: 'something'}])
      expect(packageManager.getAvailablePackageNames()).toContain('something')

      waitsForPromise ->
        packageManager.uninstall {name: 'something'}

      runs ->
        expect(runArgs).toEqual ['uninstall', '--hard', 'something']
        expect(packageManager.getAvailablePackageNames()).not.toContain('something')

    it "removes the package from the core.disabledPackages list", ->
      atom.config.set('core.disabledPackages', ['something'])
      packageManager.cacheAvailablePackageNames(user: [{name: 'something'}])
      expect(atom.config.get('core.disabledPackages')).toContain('something')

      waitsForPromise ->
        packageManager.uninstall {name: 'something'}

      runs ->
        expect(atom.config.get('core.disabledPackages')).not.toContain('something')

  describe "::installAlternative", ->
    it "installs the latest version when a package version is not specified", ->
      pack =
        alternative: 'a-new-package'
        pack:
          name: 'language-test'

      installingEvent = jasmine.createSpy()
      installedEvent = jasmine.createSpy()

      packageManager.on 'package-installing-alternative', installingEvent
      packageManager.on 'package-installed-alternative', installedEvent

      spyOn(packageManager, 'uninstall').andCallFake ->
        Promise.resolve()
      spyOn(packageManager, 'install').andCallFake ->
        Promise.resolve()

      waitsForPromise ->
        packageManager.installAlternative({name: 'language-test'}, 'a-new-package')

      runs ->
        expect(packageManager.uninstall).toHaveBeenCalledWith pack.pack
        expect(packageManager.install).toHaveBeenCalledWith {name: pack.alternative}

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

  describe "::loadCompatiblePackageVersion", ->
    it "calls command", ->
      spyOn(atom, 'getVersion').andReturn('1.0.0')
      jasmine.unspy(packageManager, 'command')
      spyOn(packageManager, 'command').andCallFake (args) ->
        new Promise (resolve, reject) ->
          runArgs = args
          resolve('[]')
      spyOn(packageManager, 'parseJSON').andReturn(Promise.resolve())

      waitsForPromise ->
        packageManager.loadCompatiblePackageVersion('git-repo-name')

      runs ->
        expect(runArgs).toEqual ['view', 'git-repo-name', '--compatible', '1.0.0', '--json']

  describe "::checkNativeBuildTools", ->
    it "calls command", ->
      waitsForPromise ->
        packageManager.checkNativeBuildTools()

      runs ->
        expect(runArgs).toEqual ['install', '--check']
