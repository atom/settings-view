path = require 'path'
PackageDetailView = require '../lib/package-detail-view'
PackageManager = require '../lib/package-manager'

describe "PackageDetailView", ->
  beforeEach ->
    spyOn(PackageManager.prototype, 'loadCompatiblePackageVersion').andCallFake ->

  it "displays the grammars registered by the package", ->
    settingsPanels = null

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new PackageManager())
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
      atom.packages.activatePackage('snippets')

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new PackageDetailView(pack, new PackageManager())
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
      view = new PackageDetailView(pack, new PackageManager())
      keybindingsTable = view.find('.package-keymap-table tbody')
      expect(keybindingsTable.children().length).toBe 0

  describe "when the package is active", ->
    it "displays the correct enablement state", ->
      packageCard = null

      waitsForPromise ->
        atom.packages.activatePackage('status-bar')

      runs ->
        expect(atom.packages.isPackageActive('status-bar')).toBe(true)
        pack = atom.packages.getLoadedPackage('status-bar')
        view = new PackageDetailView(pack, new PackageManager())
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
      view = new PackageDetailView(pack, new PackageManager())
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
        view = new PackageDetailView(pack, new PackageManager())

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

        view = new PackageDetailView(pack, new PackageManager())
        expect(view.sections.find('.package-readme').text()).not.toBe normalizePackageDataReadmeError
        expect(view.sections.find('.package-readme').text().trim()).toBe 'I am a Readme!'
