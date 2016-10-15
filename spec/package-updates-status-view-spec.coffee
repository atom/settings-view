PackageUpdatesStatusView = require '../lib/package-updates-status-view'
Package = require '../lib/package'
{mockedPackageManager} = require './spec-helper'
{$} = require 'atom-space-pen-views'

describe "PackageUpdatesStatusView", ->
  [packageManager, statusBarView] = []

  beforeEach ->
    jasmine.attachToDOM(atom.views.getView(atom.workspace))
    packageManager = mockedPackageManager()
    pack = new Package({name: 'outdated-test-package', version: '0.0.1'}, packageManager)
    packageManager.outdated.push({name: pack.name, version: pack.version})

    waitsForPromise ->
      atom.packages.activatePackage('status-bar')

    runs ->
      atom.packages.emitter.emit('did-activate-all')

    waitsForPromise ->
      packageManager.getPackageList('outdated')
        .then (packages) ->
          statusBar = atom.views.getView($('status-bar'))
          statusBarView = new PackageUpdatesStatusView(statusBar, packages)

  describe "when packages are outdated", ->
    it "adds a tile to the status bar", ->
      expect(statusBarView.countLabel.text()).toBe '1 update'
