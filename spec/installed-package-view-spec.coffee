path = require 'path'
InstalledPackageView = require '../lib/installed-package-view'
PackageManager = require '../lib/package-manager'

describe "InstalledPackageView", ->
  it "display the grammars registered by the package", ->
    pack = atom.packages.activatePackage(path.join(__dirname, 'fixtures', 'language-test'))
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
