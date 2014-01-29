{$} = require 'atom'
PackageManager = require '../lib/package-manager'
ThemePanel = require '../lib/theme-panel'

describe "ThemePanel", ->
  [panel, packageManager] = []

  beforeEach ->
    atom.packages.loadPackage('atom-light-ui')
    atom.packages.loadPackage('atom-dark-ui')
    atom.packages.loadPackage('atom-light-syntax')
    atom.packages.loadPackage('atom-dark-syntax')
    atom.themes.activatePackages()
    atom.config.set('core.themes', ['atom-dark-ui', 'atom-dark-syntax'])
    packageManager = new PackageManager
    spyOn(packageManager, 'getAvailable').andReturn []
    spyOn(atom.themes, 'setEnabledThemes').andCallThrough()
    panel = new ThemePanel(packageManager)

  afterEach ->
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
      atom.config.set('core.themes', ['atom-light-ui', 'atom-light-syntax'])
      expect(panel.uiMenu.val()).toBe 'atom-light-ui'
      expect(panel.syntaxMenu.val()).toBe 'atom-light-syntax'
