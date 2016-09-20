UpdatesPanel = require '../lib/updates-panel'
PackageManager = require '../lib/package-manager'

describe 'UpdatesPanel', ->
  panel = null

  beforeEach ->
    panel = new UpdatesPanel(new PackageManager)

  it "Shows updates when updates are available", ->
    pack =
      name: 'test-package'
      description: 'some description'
      latestVersion: '99.0.0'
      version: '1.0.0'

    # skip packman stubbing
    panel.beforeShow(updates: [pack])
    expect(panel.updatesContainer.children().length).toBe(1)

  it "Shows a message when updates are not available", ->
    panel.beforeShow(updates: [])
    expect(panel.updatesContainer.children().length).toBe(0)
    expect(panel.noUpdatesMessage.css('display')).not.toBe('none')

  describe "when the 'Update All' button is clicked", ->
    it "attempts to update all packages and prompts to restart if at least one package updated successfully", ->
      packA =
        name: 'test-package-a'
        description: 'some description'
        latestVersion: '99.0.0'
        version: '1.0.0'
      packB =
        name: 'test-package-b'
        description: 'some description'
        latestVersion: '99.0.0'
        version: '1.0.0'
      packC =
        name: 'test-package-c'
        description: 'some description'
        latestVersion: '99.0.0'
        version: '1.0.0'

      # skip packman stubbing
      panel.beforeShow(updates: [packA, packB, packC])

      [cardA, cardB, cardC] = panel.getPackageCards()

      [resolveA, rejectB, resolveC] = []

      spyOn(cardA, 'update').andReturn(new Promise((resolve) -> resolveA = resolve))
      spyOn(cardB, 'update').andReturn(new Promise((resolve, reject) -> rejectB = reject))
      spyOn(cardC, 'update').andReturn(new Promise((resolve) -> resolveC = resolve))

      expect(atom.notifications.getNotifications().length).toBe 0

      panel.updateAll()

      resolveA()
      rejectB('Error updating package')

      waits 0
      runs ->
        expect(atom.notifications.getNotifications().length).toBe 0

        resolveC()

      waits 0
      runs ->
        notifications = atom.notifications.getNotifications()
        expect(notifications.length).toBe 1

        spyOn(atom, 'restartApplication')
        notifications[0].options.buttons[0].onDidClick()
        expect(atom.restartApplication).toHaveBeenCalled()
