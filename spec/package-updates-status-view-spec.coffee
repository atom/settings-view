{$} = require 'atom-space-pen-views'
PackageManager = require '../lib/package-manager'

describe "package updates status view", ->
  beforeEach ->
    outdatedPackage =
      name: 'out-dated'
    installedPackage =
      name: 'user-package'
    spyOn(PackageManager.prototype, 'loadCompatiblePackageVersion').andCallFake ->
    spyOn(PackageManager.prototype, 'getInstalled').andCallFake -> Promise.resolve([installedPackage])
    spyOn(PackageManager.prototype, 'getOutdated').andCallFake -> Promise.resolve([outdatedPackage])
    jasmine.attachToDOM(atom.views.getView(atom.workspace))

    waitsForPromise ->
      atom.packages.activatePackage('status-bar')

    waitsForPromise ->
      atom.packages.activatePackage('settings-view')

    runs ->
      atom.packages.emitter.emit('did-activate-all')

  describe "when packages are outdated", ->
    it "adds a tile to the status bar", ->
      expect($('status-bar .package-updates-status-view').text()).toBe '1 update'
