path = require 'path'

_ = require 'underscore-plus'
CSON = require 'season'
Q = require 'q'

PackageManager = require '../lib/package-manager'
ThemesPanel = require '../lib/themes-panel'
SettingsView = require '../lib/settings-view'

describe "ThemesPanel", ->
  [panel, packageManager, reloadedHandler] = []
  settingsView = null

  beforeEach ->
    settingsView = new SettingsView
    atom.packages.loadPackage('atom-light-ui')
    atom.packages.loadPackage('atom-dark-ui')
    atom.packages.loadPackage('atom-light-syntax')
    atom.packages.loadPackage('atom-dark-syntax')
    atom.packages.packageDirPaths.push(path.join(__dirname, 'fixtures'))
    atom.config.set('core.themes', ['atom-dark-ui', 'atom-dark-syntax'])
    reloadedHandler = jasmine.createSpy('reloadedHandler')
    atom.themes.onDidChangeActiveThemes(reloadedHandler)
    atom.themes.activatePackages()

    waitsFor "themes to be reloaded", ->
      reloadedHandler.callCount is 1

    runs ->
      packageManager = new PackageManager
      themeMetadata = CSON.readFileSync(path.join(__dirname, 'fixtures', 'a-theme', 'package.json'))
      spyOn(packageManager, 'getFeatured').andCallFake (callback) ->
        Q([themeMetadata])
      panel = new ThemesPanel(packageManager)
      settingsView.addPanel('Themes', null, -> panel)

      # Make updates synchronous
      spyOn(panel, 'scheduleUpdateThemeConfig').andCallFake -> @updateThemeConfig()

  afterEach ->
    atom.packages.unloadPackage('a-theme') if atom.packages.isPackageLoaded('a-theme')
    atom.themes.deactivateThemes()

  it "selects the active syntax and UI themes", ->
    expect(panel.uiMenu.val()).toBe 'atom-dark-ui'
    expect(panel.syntaxMenu.val()).toBe 'atom-dark-syntax'

  describe "when a UI theme is selected", ->
    it "updates the 'core.themes' config key with the selected UI theme", ->
      panel.uiMenu.val('atom-light-ui').trigger('change')
      expect(atom.config.get('core.themes')).toEqual ['atom-light-ui', 'atom-dark-syntax']

  describe "when a syntax theme is selected", ->
    it "updates the 'core.themes' config key with the selected syntax theme", ->
      panel.syntaxMenu.val('atom-light-syntax').trigger('change')
      expect(atom.config.get('core.themes')).toEqual ['atom-dark-ui', 'atom-light-syntax']

  describe "when the 'core.config' key changes", ->
    it "refreshes the theme menus", ->
      reloadedHandler.reset()
      atom.config.set('core.themes', ['atom-light-ui', 'atom-light-syntax'])

      waitsFor ->
        reloadedHandler.callCount is 1

      runs ->
        expect(panel.uiMenu.val()).toBe 'atom-light-ui'
        expect(panel.syntaxMenu.val()).toBe 'atom-light-syntax'

  xdescribe "when the themes panel is navigated to", ->
    xit "focuses the search filter", ->
      settingsView.showPanel('Themes')
      expect(panel.filterEditor.hasFocus()).toBe true
