UpdatesPanel = require '../lib/updates-panel'
PackageManager = require '../lib/package-manager'

describe 'UpdatesPanel', ->
  panel = null

  beforeEach ->
    panel = new UpdatesPanel(new PackageManager)

  it "shows updates when updates are available", ->
    pack =
      name: 'test-package'
      description: 'some description'
      latestVersion: '99.0.0'
      version: '1.0.0'

    # skip packman stubbing
    panel.beforeShow(updates: [pack])
    expect(panel.updatesContainer.children().length).toBe(1)

  it "shows a message when updates are not available", ->
    panel.beforeShow(updates: [])
    expect(panel.updatesContainer.children().length).toBe(0)
    expect(panel.noUpdatesMessage.css('display')).not.toBe('none')

  describe "when the 'Update All' button is clicked", ->
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

    [cardA, cardB, cardC] = []
    [resolveA, resolveB, resolveC, rejectA, rejectB, rejectC] = []

    beforeEach ->
      # skip packman stubbing
      panel.beforeShow(updates: [packA, packB, packC])

      [cardA, cardB, cardC] = panel.getPackageCards()

      spyOn(cardA, 'update').andReturn(new Promise((resolve, reject) -> [resolveA, rejectA] = [resolve, reject]))
      spyOn(cardB, 'update').andReturn(new Promise((resolve, reject) -> [resolveB, rejectB] = [resolve, reject]))
      spyOn(cardC, 'update').andReturn(new Promise((resolve, reject) -> [resolveC, rejectC] = [resolve, reject]))

    it "attempts to update all packages and prompts to restart if at least one package updates successfully", ->
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

    it 'disables the Update All button if all updates succeed', ->
      expect(panel.updateAllButton.prop('disabled')).toBe false
      panel.updateAll()

      resolveA()
      resolveB()
      resolveC()

      waits 0
      runs ->
        expect(panel.updateAllButton.prop('disabled')).toBe true

    it 'keeps the Update All button enabled if not all updates succeed', ->
      panel.updateAll()

      resolveA()
      rejectB('Error updating package')
      resolveC()

      waits 0
      runs ->
        expect(panel.updateAllButton.prop('disabled')).toBe false
