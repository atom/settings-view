path = require 'path'
{$$} = require 'atom'
SettingsView = require '../lib/settings-view'

describe "SettingsView", ->
  settingsView = null

  beforeEach ->
    settingsView = new SettingsView
    spyOn(settingsView, "initializePanels").andCallThrough()
    window.advanceClock(10000)
    waitsFor ->
      settingsView.initializePanels.callCount > 0

  describe "serialization", ->
    it "remembers which panel was visible", ->
      settingsView.showPanel('Themes')
      newSettingsView = new SettingsView(settingsView.serialize())
      settingsView.remove()
      newSettingsView.attachToDom()
      newSettingsView.initializePanels()
      expect(newSettingsView.activePanelName).toBe 'Themes'

    it "shows the previously active panel if it is added after deserialization", ->
      settingsView.addCorePanel('Panel 1', 'panel1', -> $$ -> @div id: 'panel-1')
      settingsView.showPanel('Panel 1')
      newSettingsView = new SettingsView(settingsView.serialize())
      newSettingsView.addPanel('Panel 1', 'panel1', -> $$ -> @div id: 'panel-1')
      newSettingsView.initializePanels()
      newSettingsView.attachToDom()
      expect(newSettingsView.activePanelName).toBe 'Panel 1'

    it "shows the Settings panel if the last saved active panel name no longer exists", ->
      settingsView.addCorePanel('Panel 1', 'panel1', -> $$ -> @div id: 'panel-1')
      settingsView.showPanel('Panel 1')
      newSettingsView = new SettingsView(settingsView.serialize())
      settingsView.remove()
      newSettingsView.attachToDom()
      newSettingsView.initializePanels()
      expect(newSettingsView.activePanelName).toBe 'Settings'

    it "serializes the active panel name even when the panels were never initialized", ->
      settingsView.showPanel('Themes')
      settingsView2 = new SettingsView(settingsView.serialize())
      settingsView3 = new SettingsView(settingsView2.serialize())
      settingsView3.attachToDom()
      settingsView3.initializePanels()
      expect(settingsView3.activePanelName).toBe 'Themes'

  describe ".addCorePanel(name, iconName, view)", ->
    it "adds a menu entry to the left and a panel that can be activated by clicking it", ->
      settingsView.addCorePanel('Panel 1', 'panel1', -> $$ -> @div id: 'panel-1')
      settingsView.addCorePanel('Panel 2', 'panel2', -> $$ -> @div id: 'panel-2')

      expect(settingsView.panelMenu.find('li a:contains(Panel 1)')).toExist()
      expect(settingsView.panelMenu.find('li a:contains(Panel 2)')).toExist()
      expect(settingsView.panelMenu.children(':first')).toHaveClass 'active'

      settingsView.attachToDom()
      settingsView.panelMenu.find('li a:contains(Panel 1)').click()
      expect(settingsView.panelMenu.children('.active').length).toBe 1
      expect(settingsView.panelMenu.find('li:contains(Panel 1)')).toHaveClass('active')
      expect(settingsView.panels.find('#panel-1')).toBeVisible()
      expect(settingsView.panels.find('#panel-2')).not.toExist()
      settingsView.panelMenu.find('li a:contains(Panel 2)').click()
      expect(settingsView.panelMenu.children('.active').length).toBe 1
      expect(settingsView.panelMenu.find('li:contains(Panel 2)')).toHaveClass('active')
      expect(settingsView.panels.find('#panel-1')).toBeHidden()
      expect(settingsView.panels.find('#panel-2')).toBeVisible()

  describe ".addPackagePanel(package)", ->
    it "adds a menu entry to the left and a panel that can be activated by clicking it", ->
      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'a-theme'))

      runs ->
        pack = atom.packages.getActivePackage('a-theme')
        settingsView.addPackagePanel(pack)
        expect(settingsView.panelMenu.find('li a:contains(A Theme)')).toExist()

        settingsView.attachToDom()
        expect(settingsView.panels.find('.installed-package-view')).not.toExist()

        settingsView.panelMenu.find('li a:contains(A Theme)').click()
        expect(settingsView.panelMenu.children('.active').length).toBe 1
        expect(settingsView.panelMenu.find('li:contains(A Theme)')).toHaveClass('active')
        expect(settingsView.panels.find('.installed-package-view')).toBeVisible()
