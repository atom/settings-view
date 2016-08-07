{mockedPackageManager} = require './spec-helper'
Package = require '../lib/package'

describe "Package", ->
  [packageManager, pack] = []

  beforeEach ->
    packageManager = mockedPackageManager()
    pack = new Package({name: 'test-package'}, packageManager)

  describe "::install", ->
    it "calls install on PackageManager", ->
      waitsForPromise ->
        pack.install()

      runs ->
        expect(packageManager.install).toHaveBeenCalledWith(pack)

  describe "::update", ->
    it "calls update on PackageManager", ->
      pack.newerVersion = -> '1.1.1'

      waitsForPromise ->
        pack.update()

      runs ->
        expect(packageManager.update).toHaveBeenCalledWith(pack, '1.1.1')

  describe "::uninstall", ->
    it "calls uninstall on PackageManager", ->
      waitsForPromise ->
        pack.uninstall()

      runs ->
        expect(packageManager.uninstall).toHaveBeenCalledWith(pack)

  describe "::repositoryUrl", ->
    it "is undefined if no repository information is found", ->
      pack.repository = null
      pack.metadata = null

      expect(pack.repositoryUrl()).toBe undefined

    it "returns the url from the repository object as a string", ->
      pack.repository = {
        'url': "https://github.com/atom/settings-view.git"
      }

      expect(pack.repositoryUrl()).toBe "https://github.com/atom/settings-view"

    it "returns a https url if a git ssh url is given", ->
      pack = new Package({
        name: 'test-package'
        metadata:
          repository:
            url: 'git@github.com:atom/settings-view.git'
      }, packageManager)

      expect(pack.repositoryUrl()).toBe "https://github.com/atom/settings-view"

    it "works with a string as repository info as well", ->
      pack.repository = 'git@github.com:atom/settings-view.git'

      expect(pack.repositoryUrl()).toBe "https://github.com/atom/settings-view"

  describe "::owner", ->
    it 'returns the user part of the repository url', ->
      spyOn(pack, 'repositoryUrl').andReturn("https://github.com/atom/settings-view")
      expect(pack.owner()).toBe('atom')

  describe "::avatarUrl", ->
    it "returns a GitHub avtar url", ->
      pack.repository = {
        'url': "https://github.com/atom/settings-view.git"
      }

      expect(pack.avatarUrl()).toBe "https://avatars.githubusercontent.com/atom"

  describe "::avatar", ->
    it "calls for an asset on the package manager with the avatarUrl", ->
      url = "https://avatars.githubusercontent.com/atom"
      spyOn(pack, 'avatarUrl').andReturn(url)

      waitsForPromise ->
        pack.avatar()

      runs ->
        expect(packageManager.asset).toHaveBeenCalledWith(url)

    it "does not call for an asset when no avatarUrl is available", ->
      spyOn(pack, 'avatarUrl').andReturn(undefined)

      waitsForPromise ->
        pack.avatar()

      runs ->
        expect(packageManager.asset).not.toHaveBeenCalled()
