UpdatesPanel = require '../lib/updates-panel'
Package = require '../lib/package'
{mockedPackageManager} = require './spec-helper'

describe 'UpdatesPanel', ->
  [panel, pack, packageManager] = []

  beforeEach ->
    packageManager = mockedPackageManager()
    pack = new Package {
      name: 'test-package'
      description: 'some description'
      latestVersion: '99.0.0'
      version: '1.0.0'
    }, packageManager
    panel = new UpdatesPanel(packageManager)

  it "Shows updates when updates are available", ->
    panel.beforeShow(updates: [pack])
    expect(panel.updatesContainer.children().length).toBe(1)

  it "Shows a message when updates are not available", ->
    panel.beforeShow(updates: [])
    expect(panel.updatesContainer.children().length).toBe(0)
    expect(panel.noUpdatesMessage.css('display')).not.toBe('none')
