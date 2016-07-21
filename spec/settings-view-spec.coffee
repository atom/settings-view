path = require 'path'
{$, $$} = require 'atom-space-pen-views'
SettingsView = require '../lib/settings-view'
SnippetsProvider =
  getSnippets: -> {}

describe "SettingsView", ->
  settingsView = null

  beforeEach ->
    settingsView = new SettingsView({snippetsProvider: SnippetsProvider})
    spyOn(settingsView, "initializePanels").andCallThrough()
    window.advanceClock(10000)
    waitsFor ->
      settingsView.initializePanels.callCount > 0

  describe "serialization", ->
    it "remembers which panel was visible", ->
      settingsView.showPanel('Themes')
      newSettingsView = new SettingsView(settingsView.serialize())
      settingsView.remove()
      jasmine.attachToDOM(newSettingsView.element)
      newSettingsView.initializePanels()
      expect(newSettingsView.activePanel).toEqual {name: 'Themes', options: {}}

    it "shows the previously active panel if it is added after deserialization", ->
      settingsView.addCorePanel('Panel 1', 'panel1', -> $$ -> @div id: 'panel-1')
      settingsView.showPanel('Panel 1')
      newSettingsView = new SettingsView(settingsView.serialize())
      newSettingsView.addPanel('Panel 1', 'panel1', -> $$ -> @div id: 'panel-1')
      newSettingsView.initializePanels()
      jasmine.attachToDOM(newSettingsView.element)
      expect(newSettingsView.activePanel).toEqual {name: 'Panel 1', options: {}}

    it "shows the Settings panel if the last saved active panel name no longer exists", ->
      settingsView.addCorePanel('Panel 1', 'panel1', -> $$ -> @div id: 'panel-1')
      settingsView.showPanel('Panel 1')
      newSettingsView = new SettingsView(settingsView.serialize())
      settingsView.remove()
      jasmine.attachToDOM(newSettingsView.element)
      newSettingsView.initializePanels()
      expect(newSettingsView.activePanel).toEqual {name: 'Core', options: {}}

    it "serializes the active panel name even when the panels were never initialized", ->
      settingsView.showPanel('Themes')
      settingsView2 = new SettingsView(settingsView.serialize())
      settingsView3 = new SettingsView(settingsView2.serialize())
      jasmine.attachToDOM(settingsView3.element)
      settingsView3.initializePanels()
      expect(settingsView3.activePanel).toEqual {name: 'Themes', options: {}}

  describe ".addCorePanel(name, iconName, view)", ->
    it "adds a menu entry to the left and a panel that can be activated by clicking it", ->
      settingsView.addCorePanel('Panel 1', 'panel1', -> $$ -> @div id: 'panel-1')
      settingsView.addCorePanel('Panel 2', 'panel2', -> $$ -> @div id: 'panel-2')

      expect(settingsView.panelMenu.find('li a:contains(Panel 1)')).toExist()
      expect(settingsView.panelMenu.find('li a:contains(Panel 2)')).toExist()
      expect(settingsView.panelMenu.children(':first')).toHaveClass 'active'

      jasmine.attachToDOM(settingsView.element)
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

  describe "when the package is activated", ->
    [mainModule] = []

    openWithCommand = (command) ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), command)
      waitsFor ->
        atom.workspace.getActivePaneItem()?
      waitsFor (done) ->
        process.nextTick(done)

    beforeEach ->
      jasmine.attachToDOM(atom.views.getView(atom.workspace))
      waitsForPromise ->
        atom.packages.activatePackage('settings-view')

    describe "when the settings view is opened with a settings-view:* command", ->
      beforeEach ->
        settingsView = null

      describe "settings-view:open", ->
        it "opens the settings view", ->
          openWithCommand('settings-view:open')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Core', options: {}

      describe "settings-view:core", ->
        it "opens the core settings view", ->
          openWithCommand('settings-view:editor')
          runs ->
            openWithCommand('settings-view:core')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Core', options: uri: 'atom://config/core'

      describe "settings-view:editor", ->
        it "opens the editor settings view", ->
          openWithCommand('settings-view:editor')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Editor', options: uri: 'atom://config/editor'

      describe "settings-view:show-keybindings", ->
        it "opens the settings view to the keybindings page", ->
          openWithCommand('settings-view:show-keybindings')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Keybindings', options: uri: 'atom://config/keybindings'

      describe "settings-view:change-themes", ->
        it "opens the settings view to the themes page", ->
          openWithCommand('settings-view:change-themes')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Themes', options: uri: 'atom://config/themes'

      describe "settings-view:uninstall-themes", ->
        it "opens the settings view to the themes page", ->
          openWithCommand('settings-view:uninstall-themes')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Themes', options: uri: 'atom://config/themes'

      describe "settings-view:uninstall-packages", ->
        it "opens the settings view to the install page", ->
          openWithCommand('settings-view:uninstall-packages')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Packages', options: uri: 'atom://config/packages'

      describe "settings-view:install-packages-and-themes", ->
        it "opens the settings view to the install page", ->
          openWithCommand('settings-view:install-packages-and-themes')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Install', options: uri: 'atom://config/install'

      describe "settings-view:check-for-package-updates", ->
        it "opens the settings view to the install page", ->
          openWithCommand('settings-view:check-for-package-updates')
          runs ->
            expect(atom.workspace.getActivePaneItem().activePanel)
              .toEqual name: 'Updates', options: uri: 'atom://config/updates'

    describe "when atom.workspace.open() is used with a config URI", ->
      focusIsWithinActivePanel = ->
        activePanel = settingsView.panelsByName[settingsView.activePanel.name]
        # Return true if the element that has the focus, or its ancestors, is the activePanel
        $(document.activeElement).parents().addBack().toArray().indexOf(activePanel.element) isnt -1

      expectActivePanelToBeKeyboardScrollable = ->
        activePanel = settingsView.panelsByName[settingsView.activePanel.name]
        spyOn(activePanel, 'pageDown')
        atom.commands.dispatch(activePanel.element, 'core:page-down')
        expect(activePanel.pageDown).toHaveBeenCalled()
        spyOn(activePanel, 'pageUp')
        atom.commands.dispatch(activePanel.element, 'core:page-up')
        expect(activePanel.pageUp).toHaveBeenCalled()


      beforeEach ->
        settingsView = null

      it "opens the settings to the correct panel with atom://config/<panel-name> and that panel is keyboard-scrollable", ->
        waitsForPromise ->
          atom.workspace.open('atom://config').then (s) -> settingsView = s

        waitsFor (done) -> process.nextTick(done)
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Core', options: {}
          expect(focusIsWithinActivePanel()).toBe true
          expectActivePanelToBeKeyboardScrollable()

        waitsForPromise ->
          atom.workspace.open('atom://config/editor').then (s) -> settingsView = s

        waits 1
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Editor', options: uri: 'atom://config/editor'
          expect(focusIsWithinActivePanel()).toBe true
          expectActivePanelToBeKeyboardScrollable()

        waitsForPromise ->
          atom.workspace.open('atom://config/keybindings').then (s) -> settingsView = s

        waits 1
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Keybindings', options: uri: 'atom://config/keybindings'
          expect(focusIsWithinActivePanel()).toBe true
          expectActivePanelToBeKeyboardScrollable()

        waitsForPromise ->
          atom.workspace.open('atom://config/packages').then (s) -> settingsView = s

        waits 1
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Packages', options: uri: 'atom://config/packages'
          expect(focusIsWithinActivePanel()).toBe true
          expectActivePanelToBeKeyboardScrollable()

        waitsForPromise ->
          atom.workspace.open('atom://config/themes').then (s) -> settingsView = s

        waits 1
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Themes', options: uri: 'atom://config/themes'
          expect(focusIsWithinActivePanel()).toBe true
          expectActivePanelToBeKeyboardScrollable()

        waitsForPromise ->
          atom.workspace.open('atom://config/updates').then (s) -> settingsView = s

        waits 1
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Updates', options: uri: 'atom://config/updates'
          expect(focusIsWithinActivePanel()).toBe true
          expectActivePanelToBeKeyboardScrollable()

        waitsForPromise ->
          atom.workspace.open('atom://config/install').then (s) -> settingsView = s

        hasSystemPanel = false
        waits 1
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Install', options: uri: 'atom://config/install'
          expect(focusIsWithinActivePanel()).toBe true
          expectActivePanelToBeKeyboardScrollable()
          hasSystemPanel = settingsView.panelsByName['System']?

        if hasSystemPanel
          waitsForPromise ->
            atom.workspace.open('atom://config/system').then (s) -> settingsView = s

          waits 1
          runs ->
            expect(settingsView.activePanel)
              .toEqual name: 'System', options: uri: 'atom://config/system'
            expect(focusIsWithinActivePanel()).toBe true
            expectActivePanelToBeKeyboardScrollable()

      it "opens the package settings view with atom://config/packages/<package-name>", ->
        waitsForPromise ->
          atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'package-with-readme'))

        waitsForPromise ->
          atom.workspace.open('atom://config/packages/package-with-readme').then (s) -> settingsView = s

        waitsFor (done) -> process.nextTick(done)
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'package-with-readme', options: {
              uri: 'atom://config/packages/package-with-readme',
              pack:
                name: 'package-with-readme'
                metadata:
                  name: 'package-with-readme'
              back: 'Packages'
            }

      it "passes the URI to a pane's beforeShow() method on settings view initialization", ->
        InstallPanel = require '../lib/install-panel'
        spyOn(InstallPanel::, 'beforeShow')

        waitsForPromise ->
          atom.workspace.open('atom://config/install/package:something').then (s) -> settingsView = s

        waits 1
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Install', options: uri: 'atom://config/install/package:something'
          expect(InstallPanel::beforeShow).toHaveBeenCalledWith {uri: 'atom://config/install/package:something'}

      it "passes the URI to a pane's beforeShow() method after initialization", ->
        InstallPanel = require '../lib/install-panel'
        spyOn(InstallPanel::, 'beforeShow')

        waitsForPromise ->
          atom.workspace.open('atom://config').then (s) -> settingsView = s

        waitsFor (done) -> process.nextTick(done)

        runs ->
          expect(settingsView.activePanel).toEqual {name: 'Core', options: {}}

        waitsForPromise ->
          atom.workspace.open('atom://config/install/package:something').then (s) -> settingsView = s

        waits 1
        runs ->
          expect(settingsView.activePanel)
            .toEqual name: 'Install', options: uri: 'atom://config/install/package:something'
          expect(InstallPanel::beforeShow).toHaveBeenCalledWith {uri: 'atom://config/install/package:something'}

    describe "when the package is then deactivated", ->
      beforeEach ->
        settingsView = null

      it "calls the dispose method on all panels", ->
        openWithCommand('settings-view:open')

        waitsFor (done) -> process.nextTick(done)

        runs ->
          settingsView = atom.workspace.getActivePaneItem()
          panels = [
            settingsView.getOrCreatePanel('Core')
            settingsView.getOrCreatePanel('Editor')
            settingsView.getOrCreatePanel('Keybindings')
            settingsView.getOrCreatePanel('Packages')
            settingsView.getOrCreatePanel('Themes')
            settingsView.getOrCreatePanel('Updates')
            settingsView.getOrCreatePanel('Install')
          ]
          systemPanel = settingsView.getOrCreatePanel('System')
          if systemPanel?
            panels.push systemPanel
          for panel in panels
            spyOn(panel, 'dispose')

          atom.packages.deactivatePackage('settings-view')

          for panel in panels
            expect(panel.dispose).toHaveBeenCalled()

          return

  describe "when an installed package is clicked from the Install panel", ->
    it "displays the package details", ->
      waitsFor ->
        atom.packages.activatePackage('settings-view')

      runs ->
        settingsView.packageManager.getClient()
        spyOn(settingsView.packageManager.client, 'featuredPackages').andCallFake (callback) ->
          callback(null, [{name: 'settings-view'}])
        settingsView.showPanel('Install')

      waitsFor ->
        settingsView.find('.package-card:not(.hidden)').length > 0

      runs ->
        settingsView.find('.package-card:not(.hidden):first').click()

        packageDetail = settingsView.find('.package-detail').view()
        expect(packageDetail.title.text()).toBe 'Settings View'

  describe "when the active theme has settings", ->
    panel = null

    beforeEach ->
      atom.packages.packageDirPaths.push(path.join(__dirname, 'fixtures'))
      atom.packages.loadPackage('ui-theme-with-config')
      atom.packages.loadPackage('syntax-theme-with-config')
      atom.config.set('core.themes', ['ui-theme-with-config', 'syntax-theme-with-config'])

      reloadedHandler = jasmine.createSpy('reloadedHandler')
      atom.themes.onDidChangeActiveThemes(reloadedHandler)
      atom.themes.activatePackages()

      waitsFor "themes to be reloaded", ->
        reloadedHandler.callCount is 1

      runs ->
        settingsView.showPanel('Themes')
        panel = settingsView.find('.themes-panel').view()

    afterEach ->
      atom.themes.unwatchUserStylesheet()

    describe "when the UI theme's settings button is clicked", ->
      it "navigates to that theme's detail view", ->
        jasmine.attachToDOM(settingsView.element)
        expect(panel.activeUiThemeSettings).toBeVisible()

        panel.activeUiThemeSettings.click()
        packageDetail = settingsView.find('.package-detail').view()
        expect(packageDetail.title.text()).toBe 'Ui Theme With Config'

    describe "when the syntax theme's settings button is clicked", ->
      it "navigates to that theme's detail view", ->
        jasmine.attachToDOM(settingsView.element)
        expect(panel.activeSyntaxThemeSettings).toBeVisible()

        panel.activeSyntaxThemeSettings.click()
        packageDetail = settingsView.find('.package-detail').view()
        expect(packageDetail.title.text()).toBe 'Syntax Theme With Config'
