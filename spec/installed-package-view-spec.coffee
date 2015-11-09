path = require 'path'
PackageDetailView = require '../lib/package-detail-view'
PackageManager = require '../lib/package-manager'
PackageKeymapView = require '../lib/package-keymap-view'
_ = require 'underscore-plus'
SnippetsProvider =
  getSnippets: -> atom.config.scopedSettingsStore.propertySets

describe "PackageDetailView", ->
  beforeEach ->
    spyOn(PackageManager.prototype, 'loadCompatiblePackageVersion').andCallFake ->

  it "displays the grammars registered by the package", ->
    settingsPanels = null

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new PackageManager(), SnippetsProvider)
      settingsPanels = view.find('.package-grammars .settings-panel')

    waitsFor ->
      settingsPanels.children().length is 2

    runs ->
      expect(settingsPanels.eq(0).find('.grammar-scope').text()).toBe 'Scope: source.a'
      expect(settingsPanels.eq(0).find('.grammar-filetypes').text()).toBe 'File Types: .a, .aa, a'

      expect(settingsPanels.eq(1).find('.grammar-scope').text()).toBe 'Scope: source.b'
      expect(settingsPanels.eq(1).find('.grammar-filetypes').text()).toBe 'File Types: '

  it "displays the snippets registered by the package", ->
    snippetsTable = null

    waitsForPromise ->
      atom.packages.activatePackage('snippets').then (p) ->
        return unless p.mainModule.provideSnippets().getUnparsedSnippets?

        SnippetsProvider =
          getSnippets: -> p.mainModule.provideSnippets().getUnparsedSnippets()

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new PackageManager(), SnippetsProvider)
      snippetsTable = view.find('.package-snippets-table tbody')

    waitsFor ->
      snippetsTable.children().length is 2

    runs ->
      expect(snippetsTable.find('tr:eq(0) td:eq(0)').text()).toBe 'b'
      expect(snippetsTable.find('tr:eq(0) td:eq(1)').text()).toBe 'BAR'
      expect(snippetsTable.find('tr:eq(0) td:eq(2)').text()).toBe 'bar?'

      expect(snippetsTable.find('tr:eq(1) td:eq(0)').text()).toBe 'f'
      expect(snippetsTable.find('tr:eq(1) td:eq(1)').text()).toBe 'FOO'
      expect(snippetsTable.find('tr:eq(1) td:eq(2)').text()).toBe 'foo!'

  it "does not display keybindings from other platforms", ->
    keybindingsTable = null

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new PackageManager(), SnippetsProvider)
      keybindingsTable = view.find('.package-keymap-table tbody')
      expect(keybindingsTable.children().length).toBe 1

  describe "when the keybindings toggle is clicked", ->
    it "sets the packagesWithKeymapsDisabled config to include the package name", ->

      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

      runs ->
        pack = atom.packages.getActivePackage('language-test')
        card = new PackageKeymapView(pack)
        jasmine.attachToDOM(card[0])

        card.keybindingToggle.click()
        expect(card.keybindingToggle.prop('checked')).toBe false
        expect(_.include(atom.config.get('core.packagesWithKeymapsDisabled') ? [], 'language-test')).toBe true

        card.keybindingToggle.click()
        expect(card.keybindingToggle.prop('checked')).toBe true
        expect(_.include(atom.config.get('core.packagesWithKeymapsDisabled') ? [], 'language-test')).toBe false

  describe "when a keybinding is copied", ->
    [pack, card] = []

    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

      runs ->
        pack = atom.packages.getActivePackage('language-test')
        card = new PackageKeymapView(pack)

    describe "when the keybinding file ends in .cson", ->
      it "writes a CSON snippet to the clipboard", ->
        spyOn(atom.keymaps, 'getUserKeymapPath').andReturn 'keymap.cson'
        card.find('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          'test':
            'cmd-g': 'language-test:run'
        """

    describe "when the keybinding file ends in .json", ->
      it "writes a JSON snippet to the clipboard", ->
        spyOn(atom.keymaps, 'getUserKeymapPath').andReturn 'keymap.json'
        card.find('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          "test": {
            "cmd-g": "language-test:run"
          }
        """

  describe "when the package is active", ->
    it "displays the correct enablement state", ->
      packageCard = null

      waitsForPromise ->
        atom.packages.activatePackage('status-bar')

      runs ->
        expect(atom.packages.isPackageActive('status-bar')).toBe(true)
        pack = atom.packages.getLoadedPackage('status-bar')
        view = new PackageDetailView(pack, new PackageManager(), SnippetsProvider)
        packageCard = view.find('.package-card')

      runs ->
        # Trigger observeDisabledPackages() here
        # because it is not default in specs
        atom.packages.observeDisabledPackages()
        atom.packages.disablePackage('status-bar')
        expect(atom.packages.isPackageDisabled('status-bar')).toBe(true)
        expect(packageCard.hasClass('disabled')).toBe(true)

  describe "when the package is not active", ->
    it "displays the correct enablement state", ->
      atom.packages.loadPackage('status-bar')
      expect(atom.packages.isPackageActive('status-bar')).toBe(false)
      pack = atom.packages.getLoadedPackage('status-bar')
      view = new PackageDetailView(pack, new PackageManager(), SnippetsProvider)
      packageCard = view.find('.package-card')

      # Trigger observeDisabledPackages() here
      # because it is not default in specs
      atom.packages.observeDisabledPackages()
      atom.packages.disablePackage('status-bar')
      expect(atom.packages.isPackageDisabled('status-bar')).toBe(true)
      expect(packageCard.hasClass('disabled')).toBe(true)

    it "still loads the config schema for the package", ->
      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))

      waitsFor ->
        atom.packages.isPackageLoaded('package-with-config') is true

      runs ->
        expect(atom.config.get('package-with-config.setting')).toBe undefined

        pack = atom.packages.getLoadedPackage('package-with-config')
        view = new PackageDetailView(pack, new PackageManager(), SnippetsProvider)

        expect(atom.config.get('package-with-config.setting')).toBe 'something'

  describe "when the package was not installed from atom.io", ->
    normalizePackageDataReadmeError = 'ERROR: No README data found!'

    it "still displays the Readme", ->
      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-readme'))

      waitsFor ->
        atom.packages.isPackageLoaded('package-with-readme') is true

      runs ->
        pack = atom.packages.getLoadedPackage('package-with-readme')
        expect(pack.metadata.readme).toBe normalizePackageDataReadmeError

        view = new PackageDetailView(pack, new PackageManager(), SnippetsProvider)
        expect(view.sections.find('.package-readme').text()).not.toBe normalizePackageDataReadmeError
        expect(view.sections.find('.package-readme').text().trim()).toBe 'I am a Readme!'
