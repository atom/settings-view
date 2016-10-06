{$} = require 'atom-space-pen-views'
PackageManager = require '../lib/package-manager'

describe "package updates status view", ->
  beforeEach ->
    outdatedPackage1 =
      name: 'out-dated-1'
    outdatedPackage2 =
      name: 'out-dated-2'
    installedPackage =
      name: 'user-package'
    spyOn(PackageManager.prototype, 'loadCompatiblePackageVersion').andCallFake ->
    spyOn(PackageManager.prototype, 'getInstalled').andCallFake -> Promise.resolve([installedPackage])
    spyOn(PackageManager.prototype, 'getOutdated').andCallFake -> Promise.resolve([outdatedPackage1, outdatedPackage2])
    jasmine.attachToDOM(atom.views.getView(atom.workspace))

    waitsForPromise ->
      atom.packages.activatePackage('status-bar')

    waitsForPromise ->
      atom.packages.activatePackage('settings-view')

    runs ->
      atom.packages.emitter.emit('did-activate-all')
      expect($('status-bar .package-updates-status-view')).toExist()

  describe "when packages are outdated", ->
    it "adds a tile to the status bar", ->
      expect($('status-bar .package-updates-status-view').text()).toBe '2 updates'

  describe "when the tile is clicked", ->
    it "opens the Available Updates panel", ->
      spyOn(atom.commands, 'dispatch').andCallFake ->

      $('status-bar .package-updates-status-view').click()
      expect(atom.commands.dispatch).toHaveBeenCalledWith(atom.views.getView(atom.workspace), 'settings-view:check-for-package-updates')

    it "does not destroy the tile", ->
      $('status-bar .package-updates-status-view').click()
      expect($('status-bar .package-updates-status-view')).toExist()

  describe "when a package is updated", ->
    it "updates the tile", ->
      # TODO
      # expect($('status-bar .package-updates-status-view').text()).toBe '1 update'

  describe "when there are no more updates", ->
    it "destroys the tile", ->
      # TODO
      # expect($('status-bar .package-updates-status-view')).not.toExist()

  describe "when an update becomes available for a package", ->
    it "updates the tile", ->
      # TODO
      # expect($('status-bar .package-updates-status-view').text()).toBe '3 updates'

  describe "when updates are checked for multiple times and no new updates are available", ->
    it "does not keep updating the tile", ->
      # TODO
      # expect($('status-bar .package-updates-status-view').text()).toBe '2 updates'
