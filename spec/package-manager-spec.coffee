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

  describe "::getListArguments", ->
    [args] = []

    beforeEach ->
      args = null

    it "returns an array of arguments for a list from PACKAGE_LISTS", ->
      waitsForPromise ->
        packageManager.getListArguments('installed:packages')
          .then (listArgs) ->
            args = listArgs

      runs ->
        expect(args).toEqual packageManager.PACKAGE_LISTS['installed:packages']

    it "replaces 'compatible' with the flag and current atom version", ->
      waitsForPromise ->
        packageManager.getListArguments('outdated')
          .then (listArgs) ->
            args = listArgs

      runs ->
        expect(args).toEqual [ 'outdated', '--compatible', atom.getVersion() ]

  describe "::getPackageList", ->
    [list, returnedList] = []

    beforeEach ->
      list = new List 'name'

    it "returns list for the given listName", ->
      spyOn(packageManager, "storedList").andReturn(list)
      spyOn(packageManager, "storeList")
      spyOn(packageManager, "cachedList").andReturn(list)

      waitsForPromise ->
        packageManager.getPackageList('installed:packages')
          .then (result) ->
            returnedList = result

      runs ->
        expect(packageManager.storedList).toHaveBeenCalled()
        expect(packageManager.storeList).not.toHaveBeenCalled()
        expect(returnedList).toBe list

    describe "when no list is stored", ->
      it "gets, stores and returns a list for the given listName", ->
        spyOn(packageManager, "storedList").andReturn(undefined)
        spyOn(packageManager, "storeList")
        spyOn(packageManager, "cachedList").andReturn(list)

        waitsForPromise ->
          packageManager.getPackageList('installed:packages')
            .then (result) ->
              returnedList = result

        runs ->
          expect(packageManager.storeList).toHaveBeenCalled()
          expect(returnedList).toBe list

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

    packageManager.getPackageList('installed:packages')
      .catch (error) ->
        expect(error.message).toBe "Fetching results for installed:packages failed"

    packageManager.getPackageList('outdated')
      .catch (error) ->
        expect(error.message).toBe "Fetching results for outdated failed"

    packageManager.getPackageList('featured:packages')
      .catch (error) ->
        expect(error.message).toBe "Fetching results for featured:packages failed"

    packageManager.view('foo')
      .catch (error) ->
        expect(error.message).toBe "Fetching package 'foo' failed."

    packageManager.install(new Package ({name: 'foo', version: '1.0.0'}))
      .catch (error) ->
        expect(error.message).toBe "Installing \u201Cfoo@1.0.0\u201D failed."
        expect(error.packageInstallError).toBe true
        expect(error.stderr).toContain noSuchCommandError

    packageManager.uninstall(new Package({name: 'foo'}))
      .catch (error) ->
        expect(error.message).toBe "Uninstalling \u201Cfoo\u201D failed."
        expect(error.stderr).toContain noSuchCommandError

    packageManager.update(new Package({name: 'foo'}), '1.0.0')
      .catch (error) ->
        expect(error.message).toBe "Updating to \u201Cfoo@1.0.0\u201D failed."
        expect(error.packageInstallError).toBe true
        expect(error.stderr).toContain noSuchCommandError

    packageManager.loadCompatiblePackageVersion('foo')
      .catch (error) ->
        expect(error.message).toBe "Fetching package 'foo' failed."


  describe "::install()", ->
    it "installs the latest version when a package version is not specified", ->
      waitsForPromise ->
        packageManager.install new Package({name: 'something'})

      runs ->
        expect(packageManager.command)
          .toHaveBeenCalledWith(['install', 'something', '--json'], "Installing \u201Csomething\u201D failed.")

    it "installs the package@version when a version is specified", ->
      waitsForPromise ->
        packageManager.install new Package({name: 'something', version: '0.2.3'})

      runs ->
        expect(packageManager.command)
          .toHaveBeenCalledWith(['install', 'something@0.2.3', '--json'], "Installing \u201Csomething@0.2.3\u201D failed.")

    it "installs and loads the package", ->
      waitsForPromise ->
        packageManager.install new Package({name: 'something', version: '0.2.3'})

      runs ->
        expect(atom.packages.loadPackage).toHaveBeenCalledWith 'something'

    describe "git url installation", ->
      it 'installs https:// urls', ->
        url = "https://github.com/user/repo.git"

        waitsForPromise ->
          packageManager.install new Package({name: url})

        runs ->
          expect(packageManager.command)
            .toHaveBeenCalledWith(['install', 'https://github.com/user/repo.git', '--json'], "Installing \u201Chttps://github.com/user/repo.git\u201D failed.")

      it 'installs git@ urls', ->
        url = "git@github.com:user/repo.git"

        waitsForPromise ->
          packageManager.install new Package({name: url})

        runs ->
          expect(packageManager.command)
            .toHaveBeenCalledWith(['install', 'git@github.com:user/repo.git', '--json'], "Installing \u201Cgit@github.com:user/repo.git\u201D failed.")

      it 'installs user/repo url shortcuts', ->
        url = "user/repo"

        waitsForPromise ->
          packageManager.install new Package({name: url})

        runs ->
          expect(packageManager.command)
            .toHaveBeenCalledWith(['install', 'user/repo', '--json'], "Installing \u201Cuser/repo\u201D failed.")

      it 'installs and activates git pacakges with names different from the repo name', ->
        spyOn(atom.packages, 'activatePackage')

        jasmine.unspy(packageManager, 'command')
        spyOn(packageManager, 'command').andCallFake (args) ->
          new Promise (resolve, reject) ->
            jsonString = '{"metadata":{"name":"real-package-name"}}'
            resolve(jsonString)

        waitsForPromise ->
          packageManager.install(new Package(name: 'git-repo-name'))

        runs ->
          expect(atom.packages.activatePackage).toHaveBeenCalledWith 'real-package-name'

      # TODO: Verify event emition per install, update and uninstall functions
      # it 'emits an installed event with a copy of the pack including the full package metadata', ->
      #   originalPackObject = name: 'git-repo-name', otherData: {will: 'beCopied'}
      #
      #   jasmine.unspy(packageManager, 'command')
      #   spyOn(packageManager, 'command').andCallFake (args) ->
      #     new Promise (resolve, reject) ->
      #       runArgs = args
      #       json = '{"metadata":{"name":"real-package-name", "moreInfo":"yep"}}'
      #       resolve(json)
      #
      #   waitsForPromise ->
      #     packageManager.install(originalPackObject)
      #
      #   runs ->
      #     installEmittedCount = 0
      #     for call in packageManager.emitPackageEvent.calls
      #       if call.args[0] is "installed"
      #         expect(call.args[1]).not.toEqual originalPackObject
      #         expect(call.args[1].moreInfo).toEqual "yep"
      #         expect(call.args[1].otherData).toBe originalPackObject.otherData
      #         installEmittedCount++
      #     expect(installEmittedCount).toBe 1

  describe "::uninstall()", ->
    it "uninstalls the package and removes the package from the available package names", ->
      waitsForPromise ->
        packageManager.uninstall new Package({name: 'something'})

      runs ->
        expect(packageManager.command)
          .toHaveBeenCalledWith(['uninstall', '--hard', 'something'], "Uninstalling \u201Csomething\u201D failed.")

    it "removes the package from the core.disabledPackages list", ->
      atom.config.set('core.disabledPackages', ['something'])
      expect(atom.config.get('core.disabledPackages')).toContain('something')

      waitsForPromise ->
        packageManager.uninstall new Package({name: 'something'})

      runs ->
        expect(atom.config.get('core.disabledPackages')).not.toContain('something')

  describe "::installAlternative", ->
    [pack, alternative] = []

    it "installs the alternative and uninstalls the other", ->
      alternative = new Package({name: 'a-new-package'})
      pack = new Package({name: 'language-test'})

      waitsForPromise ->
        packageManager.installAlternative(pack, alternative)

      runs ->
        expect(packageManager.uninstall).toHaveBeenCalledWith pack
        expect(packageManager.install).toHaveBeenCalledWith alternative

  # TODO: Move to Package
  # describe "::packageHasSettings", ->
  #   it "returns true when the pacakge has config", ->
  #     atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))
  #     expect(packageManager.packageHasSettings('package-with-config')).toBe true
  #
  #   it "returns false when the pacakge does not have config and doesn't define language grammars", ->
  #     expect(packageManager.packageHasSettings('random-package')).toBe false
  #
  #   it "returns true when the pacakge does not have config, but does define language grammars", ->
  #     packageName = 'language-test'
  #
  #     waitsForPromise ->
  #       atom.packages.activatePackage(path.join(__dirname, 'fixtures', packageName))
  #
  #     runs ->
  #       expect(packageManager.packageHasSettings(packageName)).toBe true
  #
  # describe "::loadCompatiblePackageVersion", ->
  #   it "calls command", ->
  #     spyOn(atom, 'getVersion').andReturn('1.0.0')
  #     jasmine.unspy(packageManager, 'command')
  #     spyOn(packageManager, 'command').andCallFake (args) ->
  #       new Promise (resolve, reject) ->
  #         runArgs = args
  #         resolve('[]')
  #     spyOn(packageManager, 'parseJSON').andReturn(Promise.resolve())
  #
  #     waitsForPromise ->
  #       packageManager.loadCompatiblePackageVersion('git-repo-name')
  #
  #     runs ->
  #       expect(runArgs).toEqual ['view', 'git-repo-name', '--compatible', '1.0.0', '--json']

  describe "::checkNativeBuildTools", ->
    it "calls command", ->
      waitsForPromise ->
        packageManager.checkNativeBuildTools()

      runs ->
        expect(packageManager.command).toHaveBeenCalledWith(['install', '--check'])
