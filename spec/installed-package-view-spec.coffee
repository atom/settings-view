path = require 'path'
{WorkspaceView} = require 'atom'
InstalledPackageView = require '../lib/installed-package-view'
PackageManager = require '../lib/package-manager'

describe "InstalledPackageView", ->
  it "display the grammars registered by the package", ->
    grammarTable = null

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new InstalledPackageView(pack, new PackageManager())
      grammarTable = view.find('.package-grammars-table tbody')

    waitsFor ->
      grammarTable.children().length is 2

    runs ->
      expect(grammarTable.find('tr:eq(0) td:eq(0)').text()).toBe 'A Grammar'
      expect(grammarTable.find('tr:eq(0) td:eq(1)').text()).toBe '.a, .aa, a'
      expect(grammarTable.find('tr:eq(0) td:eq(2)').text()).toBe 'source.a'

      expect(grammarTable.find('tr:eq(1) td:eq(0)').text()).toBe 'B Grammar'
      expect(grammarTable.find('tr:eq(1) td:eq(1)').text()).toBe ''
      expect(grammarTable.find('tr:eq(1) td:eq(2)').text()).toBe 'source.b'

  it "displays the snippets registered by the package", ->
    snippetsTable = null
    atom.workspaceView = new WorkspaceView()

    waitsForPromise ->
      atom.packages.activatePackage('snippets')

    waitsForPromise ->
      atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))

    runs ->
      pack = atom.packages.getActivePackage('language-test')
      view = new InstalledPackageView(pack, new PackageManager())
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
