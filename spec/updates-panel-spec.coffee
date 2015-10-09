UpdatesPanel = require '../lib/updates-panel'
PackageManager = require '../lib/package-manager'

describe 'UpdatesPanel', ->
  beforeEach ->
    @panel = new UpdatesPanel(new PackageManager)

  it "Shows updates when updates are available", ->
    pack =
      name: 'test-package'
      description: 'some description'
      latestVersion: '99.0.0'
      version: '1.0.0'

    # skip packman stubbing
    @panel.beforeShow(updates: [pack])
    expect(@panel.updatesContainer.children().length).toBe(1)

  it "Shows a message when updates are not available", ->
    @panel.beforeShow(updates: [])
    expect(@panel.updatesContainer.children().length).toBe(0)
    expect(@panel.noUpdatesMessage.css('display')).not.toBe('none')
