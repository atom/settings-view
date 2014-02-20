path = require 'path'

{$} = require 'atom'
CSON = require 'season'
Q = require 'q'

PackageManager = require '../lib/package-manager'
ThemesPanel = require '../lib/themes-panel'

describe "ThemesPanel", ->
  [panel, packageManager, reloadedHandler] = []

  beforeEach ->
    atom.packages.loadPackage('atom-light-ui')
    atom.packages.loadPackage('atom-dark-ui')
    atom.packages.loadPackage('atom-light-syntax')
    atom.packages.loadPackage('atom-dark-syntax')
    atom.packages.packageDirPaths.push(path.join(__dirname, 'fixtures'))
    atom.config.set('core.themes', ['atom-dark-ui', 'atom-dark-syntax'])
    reloadedHandler = jasmine.createSpy('reloadedHandler')
    atom.themes.on 'reloaded', reloadedHandler
    atom.themes.activatePackages()

    waitsFor ->
      reloadedHandler.callCount is 1

    runs ->
      packageManager = new PackageManager
      themeMetadata = CSON.readFileSync(path.join(__dirname, 'fixtures', 'a-theme', 'package.json'))
      spyOn(packageManager, 'getFeatured').andCallFake (callback) ->
        Q([themeMetadata])
      spyOn(atom.themes, 'setEnabledThemes').andCallThrough()
      panel = new ThemesPanel(packageManager)

  afterEach ->
    atom.packages.unloadPackage('a-theme') if atom.packages.isPackageLoaded('a-theme')
    atom.themes.deactivateThemes()

  it "selects the active syntax and UI themes", ->
    expect(panel.uiMenu.val()).toBe 'atom-dark-ui'
    expect(panel.syntaxMenu.val()).toBe 'atom-dark-syntax'

  describe "when a UI theme is selected", ->
    it "updates the 'core.themes' config key with the selected UI theme", ->
      jasmine.unspy(window, 'setTimeout')
      panel.uiMenu.val('atom-light-ui').trigger('change')

      waitsFor ->
        atom.themes.setEnabledThemes.callCount > 0

      runs ->
        expect(atom.config.get('core.themes')).toEqual ['atom-light-ui', 'atom-dark-syntax']

  describe "when a syntax theme is selected", ->
    it "updates the 'core.themes' config key with the selected syntax theme", ->
      jasmine.unspy(window, 'setTimeout')
      panel.syntaxMenu.val('atom-light-syntax').trigger('change')

      waitsFor ->
        atom.themes.setEnabledThemes.callCount > 0

      runs ->
        expect(atom.config.get('core.themes')).toEqual ['atom-dark-ui', 'atom-light-syntax']

  describe "when the 'core.config' key is changes", ->
    it "refreshes the theme menus", ->
      reloadedHandler.reset()
      atom.config.set('core.themes', ['atom-light-ui', 'atom-light-syntax'])

      waitsFor ->
        reloadedHandler.callCount is 1

      runs ->
        expect(panel.uiMenu.val()).toBe 'atom-light-ui'
        expect(panel.syntaxMenu.val()).toBe 'atom-light-syntax'

  describe "when a theme is installed", ->
    it "adds it to the menu", ->
      expect(panel.syntaxMenu.find('option[value=a-theme]').length).toBe 0

      themeView = null
      waitsFor ->
        themeView = panel.find('.available-package-view').view()
        themeView?

      runs ->
        spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
          process.nextTick -> callback(0)
        themeView.installButton.click()
        expect(themeView.installButton.prop('disabled')).toBe true

      waitsFor ->
        panel.syntaxMenu.find('option[value=a-theme]').length is 1

      runs ->
        expect(themeView.status).toHaveClass 'icon-check'
        expect(themeView.installButton.prop('disabled')).toBe true

  describe "when a theme fails to install", ->
    it "displays an error", ->
      expect(panel.syntaxMenu.find('option[value=a-theme]').length).toBe 0

      themeView = null
      waitsFor ->
        themeView = panel.find('.available-package-view').view()
        themeView?

      runs ->
        spyOn(console, 'error')
        spyOn(packageManager, 'runCommand').andCallFake (args, callback) ->
          process.nextTick -> callback(-1, 'failed', 'failed')
        themeView.installButton.click()
        expect(themeView.installButton.prop('disabled')).toBe true

      waitsFor ->
        themeView.status.hasClass('icon-alert')

      runs ->
        expect(console.error).toHaveBeenCalled()
        expect(themeView.installButton.prop('disabled')).toBe false
        expect(panel.syntaxMenu.find('option[value=a-theme]').length).toBe 0
