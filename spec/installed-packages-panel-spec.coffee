path = require 'path'

fs = require 'fs-plus'
InstalledPackagesPanel = require '../lib/installed-packages-panel'
PackageManager = require '../lib/package-manager'
PackageCard = require '../lib/package-card'

describe 'InstalledPackagesPanel', ->
  describe 'when the packages are loading', ->
    it 'filters packages by name once they have loaded', ->
      @packageManager = new PackageManager
      @installed = JSON.parse fs.readFileSync(path.join(__dirname, 'fixtures', 'installed.json'))
      spyOn(@packageManager, 'getOutdated').andReturn new Promise ->
      spyOn(@packageManager, 'loadCompatiblePackageVersion').andCallFake ->
      spyOn(@packageManager, 'getInstalled').andReturn Promise.resolve(@installed)
      @panel = new InstalledPackagesPanel(@packageManager)
      @panel.filterEditor.getModel().setText('user-')
      window.advanceClock(@panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)

      waitsFor ->
        @packageManager.getInstalled.callCount is 1 and @panel.communityCount.text().indexOf('…') < 0

      runs ->
        expect(@panel.communityCount.text().trim()).toBe '1/1'
        expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

        expect(@panel.coreCount.text().trim()).toBe '0/1'
        expect(@panel.corePackages.find('.package-card:not(.hidden)').length).toBe 0

        expect(@panel.devCount.text().trim()).toBe '0/1'
        expect(@panel.devPackages.find('.package-card:not(.hidden)').length).toBe 0

        expect(@panel.deprecatedCount.text().trim()).toBe '0/0'
        expect(@panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 0

  describe 'when the packages have finished loading', ->
    beforeEach ->
      @packageManager = new PackageManager
      @installed = JSON.parse fs.readFileSync(path.join(__dirname, 'fixtures', 'installed.json'))
      spyOn(@packageManager, 'getOutdated').andReturn new Promise ->
      spyOn(@packageManager, 'loadCompatiblePackageVersion').andCallFake ->
      spyOn(@packageManager, 'getInstalled').andReturn Promise.resolve(@installed)
      @panel = new InstalledPackagesPanel(@packageManager)

      waitsFor ->
        @packageManager.getInstalled.callCount is 1 and @panel.communityCount.text().indexOf('…') < 0

    it 'shows packages', ->
      expect(@panel.communityCount.text().trim()).toBe '1'
      expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(@panel.coreCount.text().trim()).toBe '1'
      expect(@panel.corePackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(@panel.devCount.text().trim()).toBe '1'
      expect(@panel.devPackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(@panel.deprecatedCount.text().trim()).toBe '0'
      expect(@panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 0

    it 'filters packages by name', ->
      @panel.filterEditor.getModel().setText('user-')
      window.advanceClock(@panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)
      expect(@panel.communityCount.text().trim()).toBe '1/1'
      expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(@panel.coreCount.text().trim()).toBe '0/1'
      expect(@panel.corePackages.find('.package-card:not(.hidden)').length).toBe 0

      expect(@panel.devCount.text().trim()).toBe '0/1'
      expect(@panel.devPackages.find('.package-card:not(.hidden)').length).toBe 0

      expect(@panel.deprecatedCount.text().trim()).toBe '0/0'
      expect(@panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 0

    it 'adds newly installed packages to the list', ->
      [installCallback] = []
      spyOn(@packageManager, 'runCommand').andCallFake (args, callback) ->
        installCallback = callback
        onWillThrowError: ->
      spyOn(atom.packages, 'activatePackage').andCallFake (name) =>
        @installed.user.push {name}

      expect(@panel.communityCount.text().trim()).toBe '1'
      expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      @packageManager.install({name: 'another-user-package'})
      installCallback(0, '', '')

      advanceClock InstalledPackagesPanel.loadPackagesDelay
      waits 1
      runs ->
        expect(@panel.communityCount.text().trim()).toBe '2'
        expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 2

    it 'removes uninstalled packages from the list', ->
      [uninstallCallback] = []
      spyOn(@packageManager, 'runCommand').andCallFake (args, callback) ->
        uninstallCallback = callback
        onWillThrowError: ->
      spyOn(@packageManager, 'unload').andCallFake (name) =>
        @installed.user = []

      expect(@panel.communityCount.text().trim()).toBe '1'
      expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      @packageManager.uninstall({name: 'user-package'})
      uninstallCallback(0, '', '')

      advanceClock InstalledPackagesPanel.loadPackagesDelay
      waits 1
      runs ->
        expect(@panel.communityCount.text().trim()).toBe '0'
        expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 0

    it 'correctly handles deprecated packages', ->
      resolve = null
      promise = new Promise (r) -> resolve = r
      jasmine.unspy(@packageManager, 'getOutdated')
      spyOn(@packageManager, 'getOutdated').andReturn(promise)
      jasmine.attachToDOM(@panel[0])

      [updateCallback] = []
      spyOn(atom.packages, 'isDeprecatedPackage').andCallFake =>
        return true if @installed.user[0].version is '1.0.0'
        false
      spyOn(@packageManager, 'runCommand').andCallFake (args, callback) ->
        updateCallback = callback
        onWillThrowError: ->
          atom.packages.activatePackage
      spyOn(atom.packages, 'activatePackage').andCallFake (name) =>
        @installed.user[0].version = '1.1.0'

      expect(@panel.deprecatedSection).not.toBeVisible()
      @panel.loadPackages()

      waits 1
      runs ->
        expect(@panel.deprecatedSection).toBeVisible()
        expect(@panel.deprecatedCount.text().trim()).toBe '1'
        expect(@panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 1

        spyOn(PackageCard::, 'displayAvailableUpdate')
        resolve([{name: 'user-package', latestVersion: '1.1.0'}])

      waits 1
      runs ->
        expect(PackageCard::displayAvailableUpdate).toHaveBeenCalledWith('1.1.0')
        @packageManager.update({name: 'user-package'})
        updateCallback(0, '', '')

      waits 1
      runs ->
        advanceClock InstalledPackagesPanel.loadPackagesDelay

      waits 1
      runs ->
        expect(@panel.deprecatedSection).not.toBeVisible()
        expect(@panel.deprecatedCount.text().trim()).toBe '0'
        expect(@panel.deprecatedPackages.find('.package-card:not(.hidden)').length).toBe 0

  describe 'expanding and collapsing sub-sections', ->
    beforeEach ->
      @packageManager = new PackageManager
      @installed = JSON.parse fs.readFileSync(path.join(__dirname, 'fixtures', 'installed.json'))
      spyOn(@packageManager, 'getOutdated').andReturn new Promise ->
      spyOn(@packageManager, 'loadCompatiblePackageVersion').andCallFake ->
      spyOn(@packageManager, 'getInstalled').andReturn Promise.resolve(@installed)
      spyOn(atom.packages, 'isDeprecatedPackage').andCallFake =>
        return true if @installed.user[0].version is '1.0.0'
        false

      @panel = new InstalledPackagesPanel(@packageManager)

      waitsFor ->
        @packageManager.getInstalled.callCount is 1 and @panel.communityCount.text().indexOf('…') < 0

    it 'collapses and expands a sub-section if its header is clicked', ->
      @panel.find('.sub-section.installed-packages .sub-section-heading').click()
      expect(@panel.find('.sub-section.installed-packages')).toHaveClass 'collapsed'

      expect(@panel.find('.sub-section.deprecated-packages')).not.toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.core-packages')).not.toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

      @panel.find('.sub-section.installed-packages .sub-section-heading').click()
      expect(@panel.find('.sub-section.installed-packages')).not.toHaveClass 'collapsed'

    it 'can collapse and expand any of the sub-sections', ->
      expect(@panel.find('.sub-section-heading.has-items').length).toBe 4

      @panel.find('.sub-section-heading.has-items').click()
      expect(@panel.find('.sub-section.deprecated-packages')).toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.installed-packages')).toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.core-packages')).toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.dev-packages')).toHaveClass 'collapsed'

      @panel.find('.sub-section-heading.has-items').click()
      expect(@panel.find('.sub-section.deprecated-packages')).not.toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.installed-packages')).not.toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.core-packages')).not.toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

    it 'can collapse sub-sections when filtering', ->
      @panel.filterEditor.getModel().setText('user-')
      window.advanceClock(@panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)

      hasItems = @panel.find('.sub-section-heading.has-items')
      expect(hasItems.length).toBe 2
      expect(hasItems.text()).toMatch /Deprecated Packages/
      expect(hasItems.text()).toMatch /Community Packages/

  describe 'when there are no packages', ->
    beforeEach ->
      @packageManager = new PackageManager
      @installed =
        dev: []
        user: []
        core: []
      spyOn(@packageManager, 'getOutdated').andReturn new Promise ->
      spyOn(@packageManager, 'loadCompatiblePackageVersion').andCallFake ->
      spyOn(@packageManager, 'getInstalled').andReturn Promise.resolve(@installed)
      @panel = new InstalledPackagesPanel(@packageManager)

      waitsFor ->
        @packageManager.getInstalled.callCount is 1 and @panel.communityCount.text().indexOf('…') < 0

    it 'has a count of zero in all headings', ->
      expect(@panel.find('.section-heading-count').text()).toMatch /^0+$/
      expect(@panel.find('.sub-section .icon-package').length).toBe 4
      expect(@panel.find('.sub-section .icon-package.has-items').length).toBe 0

    it 'can not collapse and expand any of the sub-sections', ->
      @panel.find('.sub-section .icon-package').click()
      expect(@panel.find('.sub-section.deprecated-packages')).not.toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.installed-packages')).not.toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.core-packages')).not.toHaveClass 'collapsed'
      expect(@panel.find('.sub-section.dev-packages')).not.toHaveClass 'collapsed'

    it 'does not allow collapsing on any section when filtering', ->
      @panel.filterEditor.getModel().setText('user-')
      window.advanceClock(@panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)

      expect(@panel.find('.section-heading-count').text()).toMatch /^(0\/0)+$/
      expect(@panel.find('.sub-section .icon-package').length).toBe 4
      expect(@panel.find('.sub-section .icon-paintcan.has-items').length).toBe 0
