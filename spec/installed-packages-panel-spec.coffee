{mockedPackageManager} = require './spec-helper'
path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'
InstalledPackagesPanel = require '../lib/installed-packages-panel'
PackageCard = require '../lib/package-card'
Package = require '../lib/package'

describe 'InstalledPackagesPanel', ->
  [packageManager, panel, deprecatedPack] = []

  beforeEach ->
    packageManager = mockedPackageManager(
      installedPackages: CSON.readFileSync(path.join(__dirname, 'fixtures', 'installed.json'))
    )
    spyOn(atom.packages, 'activatePackage').andReturn(true)
    jasmine.unspy(atom.packages, 'loadPackage')
    spyOn(atom.packages, 'loadPackage').andReturn(true)

    panel = new InstalledPackagesPanel(packageManager)

  afterEach ->
    [packageManager, panel, deprecatedPack] = []

  describe 'when the packages are loading', ->
    it 'filters packages by name once they have loaded', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        panel.filterEditor.getModel().setText('user-')
        window.advanceClock(panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)

        expect(panel.userCount.text().trim()).toBe '1/1'
        expect(panel.userPackages.find('.package-card:not(.hidden)').length).toBe 1

        expect(panel.coreCount.text().trim()).toBe '0/1'
        expect(panel.corePackages.find('.package-card:not(.hidden)').length).toBe 0

        expect(panel.devCount.text().trim()).toBe '0/1'
        expect(panel.devPackages.find('.package-card:not(.hidden)').length).toBe 0

        expect(panel.deprecatedCount.text().trim()).toBe '0/0'
        expect(panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 0

  describe 'when the packages have finished loading', ->
    it 'shows packages', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        expect(panel.userCount.text().trim()).toBe '1'
        expect(panel.userPackages.find('.package-card:not(.hidden)').length).toBe 1

        expect(panel.coreCount.text().trim()).toBe '1'
        expect(panel.corePackages.find('.package-card:not(.hidden)').length).toBe 1

        expect(panel.devCount.text().trim()).toBe '1'
        expect(panel.devPackages.find('.package-card:not(.hidden)').length).toBe 1

        expect(panel.deprecatedCount.text().trim()).toBe '0'
        expect(panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 0

    it 'filters packages by name', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        panel.filterEditor.getModel().setText('user-')
        window.advanceClock(panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)

        expect(panel.userCount.text().trim()).toBe '1/1'
        expect(panel.userPackages.find('.package-card:not(.hidden)').length).toBe 1

        expect(panel.coreCount.text().trim()).toBe '0/1'
        expect(panel.corePackages.find('.package-card:not(.hidden)').length).toBe 0

        expect(panel.devCount.text().trim()).toBe '0/1'
        expect(panel.devPackages.find('.package-card:not(.hidden)').length).toBe 0

        expect(panel.deprecatedCount.text().trim()).toBe '0/0'
        expect(panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 0

    it 'adds newly installed packages to the list', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        expect(panel.userCount.text().trim()).toBe '1'
        expect(panel.userPackages.find('.package-card:not(.hidden)').length).toBe 1

      waitsForPromise ->
        pack = new Package({name: 'another-user-package'}, packageManager)
        packageManager.install(pack)

      waitsFor ->
        panel.userCount.text().trim() is '2'

      runs ->
        expect(panel.userCount.text().trim()).toBe '2'
        expect(panel.userPackages.find('.package-card:not(.hidden)').length).toBe 2

    it 'removes uninstalled packages from the list', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        expect(panel.userCount.text().trim()).toBe '1'
        expect(panel.userPackages.find('.package-card:not(.hidden)').length).toBe 1

      waitsForPromise ->
        pack = new Package({name: 'user-package'})
        packageManager.uninstall(pack)

      waitsFor ->
        panel.userCount.text().indexOf('1') < 0

      runs ->
        expect(panel.userCount.text().trim()).toBe '0'
        expect(panel.userPackages.find('.package-card:not(.hidden)').length).toBe 0

    it 'correctly handles deprecated packages', ->
      deprecatedPack = new Package {
        name: 'deprecated-package',
        version: '1.0.0'
      }, packageManager

      packageManager.addPackage(deprecatedPack)
      packageManager.setDeprecated(deprecatedPack.name)
      console.log 'DEP TEST'
      console.log "Package deprecated #{deprecatedPack.isDeprecated()}"

      waitsForPromise ->
        panel.loadPackages()

      waitsFor ->
        panel.deprecatedCount.text().indexOf('…') < 0

      runs ->
        expect(panel.deprecatedSection).toBeVisible()
        expect(panel.deprecatedCount.text().trim()).toBe '1'
        expect(panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 1

      waitsForPromise ->
        packageManager.update(deprecatedPack, '1.0.1')

      runs ->
        expect(panel.deprecatedSection).not.toBeVisible()
        expect(panel.deprecatedCount.text().trim()).toBe '0'
        expect(panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 0
        console.log 'DEP TEST END'

  describe 'expanding and collapsing sub-sections', ->
    it 'collapses and expands a sub-section if its header is clicked', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        panel.find('.sub-section.installed-packages .sub-section-heading').click()
        expect(panel.find('.sub-section.installed-packages')).toHaveClass 'collapsed'

        expect(panel.find('.sub-section.deprecated-packages')).not.toHaveClass 'collapsed'
        expect(panel.find('.sub-section.core-packages')).not.toHaveClass 'collapsed'
        expect(panel.find('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

        panel.find('.sub-section.installed-packages .sub-section-heading').click()
        expect(panel.find('.sub-section.installed-packages')).not.toHaveClass 'collapsed'

    it 'can collapse and expand any of the sub-sections', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        expect(panel.find('.sub-section-heading.has-items').length).toBe 4

        panel.find('.sub-section-heading.has-items').click()
        expect(panel.find('.sub-section.deprecated-packages')).toHaveClass 'collapsed'
        expect(panel.find('.sub-section.installed-packages')).toHaveClass 'collapsed'
        expect(panel.find('.sub-section.core-packages')).toHaveClass 'collapsed'
        expect(panel.find('.sub-section.dev-packages')).toHaveClass 'collapsed'

        panel.find('.sub-section-heading.has-items').click()
        expect(panel.find('.sub-section.deprecated-packages')).not.toHaveClass 'collapsed'
        expect(panel.find('.sub-section.installed-packages')).not.toHaveClass 'collapsed'
        expect(panel.find('.sub-section.core-packages')).not.toHaveClass 'collapsed'
        expect(panel.find('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

    it 'can collapse sub-sections when filtering', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      waitsFor ->
        panel.filterEditor.getModel().setText('user-')
        window.advanceClock(panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)

      runs ->
        hasItems = panel.find('.sub-section-heading.has-items')
        expect(hasItems.length).toBe 2
        expect(hasItems.text()).toMatch /Deprecated Packages/
        expect(hasItems.text()).toMatch /Community Packages/

  describe 'when there are no packages', ->
    beforeEach ->
      noinstalledPackages = {
        dev: []
        user: []
        core: []
        git: []
      }
      packageManager = mockedPackageManager(
        installedPackages: noinstalledPackages
      )
      panel = new InstalledPackagesPanel(packageManager)

    it 'has a count of zero in all headings', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        expect(panel.find('.section-heading-count').text()).toMatch /^0+$/
        expect(panel.find('.sub-section .icon-package').length).toBe 5
        expect(panel.find('.sub-section .icon-package.has-items').length).toBe 0

    it 'can not collapse and expand any of the sub-sections', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      runs ->
        panel.find('.sub-section .icon-package').click()
        expect(panel.find('.sub-section.deprecated-packages')).not.toHaveClass 'collapsed'
        expect(panel.find('.sub-section.installed-packages')).not.toHaveClass 'collapsed'
        expect(panel.find('.sub-section.core-packages')).not.toHaveClass 'collapsed'
        expect(panel.find('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

    it 'does not allow collapsing on any section when filtering', ->
      waitsFor ->
        panel.userCount.text().indexOf('…') < 0

      waitsFor ->
        panel.filterEditor.getModel().setText('user-')
        window.advanceClock(panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)

      runs ->
        expect(panel.find('.section-heading-count').text()).toMatch /^(0\/0)+$/
        expect(panel.find('.sub-section .icon-package').length).toBe 5
        expect(panel.find('.sub-section .icon-paintcan.has-items').length).toBe 0
