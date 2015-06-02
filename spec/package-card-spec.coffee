path = require 'path'
PackageCard = require '../lib/package-card'
PackageManager = require '../lib/package-manager'

fdescribe "PackageCard", ->
  [card, packageManager] = []

  beforeEach ->
    packageManager = new PackageManager()
    spyOn(packageManager, 'runCommand')

  ###
  Holy button states.

  not installed: install
  disabled: settings?, uninstall, disable
  hasDeprecations, no update: disabled-settings, uninstall, disable
  hasDeprecations, has update: update, disabled-settings, uninstall, disable
  hasAlternative; core: uninstall
  hasAlternative; package, alt not installed: install new-package
  hasAlternative; package, alt installed: uninstall
  ###

  describe "when the package is not installed", ->
    it "shows the settings, uninstall, and disable buttons", ->
      pack =
        name: 'some-package'
        version: '0.1.0'
        repository: 'http://github.com/omgwow/some-package'
      spyOn(PackageCard::, 'isDeprecated').andReturn(false)
      card = new PackageCard(pack, packageManager)

      jasmine.attachToDOM(card[0])

      expect(card.installButtonGroup).toBeVisible()
      expect(card.updateButtonGroup).not.toBeVisible()
      expect(card.installAlternativeButtonGroup).not.toBeVisible()
      expect(card.packageActionButtonGroup).not.toBeVisible()

  describe "when the package is installed", ->
    beforeEach ->
      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))
      waitsFor ->
        atom.packages.isPackageLoaded('package-with-config') is true

    it "shows the settings, uninstall, and disable buttons", ->
      atom.config.set('package-with-config.setting', 'something')
      pack = atom.packages.getLoadedPackage('package-with-config')
      spyOn(PackageCard::, 'isDeprecated').andReturn(false)
      card = new PackageCard(pack, packageManager)

      jasmine.attachToDOM(card[0])

      expect(card.updateButtonGroup).not.toBeVisible()
      expect(card.installButtonGroup).not.toBeVisible()
      expect(card.installAlternativeButtonGroup).not.toBeVisible()

      expect(card.settingsButton).toBeVisible()
      expect(card.uninstallButton).toBeVisible()
      expect(card.enablementButton).toBeVisible()
      expect(card.enablementButton.text()).toBe 'Disable'

    it "does not show the settings button when there are no settings", ->
      pack = atom.packages.getLoadedPackage('package-with-config')
      spyOn(PackageCard::, 'isDeprecated').andReturn(false)
      card = new PackageCard(pack, packageManager)

      jasmine.attachToDOM(card[0])

      expect(card.settingsButton).not.toBeVisible()
      expect(card.uninstallButton).toBeVisible()
      expect(card.enablementButton).toBeVisible()
      expect(card.enablementButton.text()).toBe 'Disable'

  ###
  hasDeprecations, no update: disabled-settings, uninstall, disable
  hasDeprecations, has update: update, disabled-settings, uninstall, disable
  hasAlternative; core: uninstall
  hasAlternative; package, alt not installed: install new-package
  hasAlternative; package, alt installed: uninstall
  ###
  describe "when the package has deprecations", ->
    beforeEach ->
      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))

      waitsFor ->
        atom.packages.isPackageLoaded('package-with-config') is true

      runs ->
        atom.config.set('package-with-config.setting', 'something')

    describe "when hasDeprecations is true and NO update is available", ->
      beforeEach ->
        spyOn(PackageCard::, 'isDeprecated').andReturn(true)
        spyOn(PackageCard::, 'getPackageDeprecationMetadata').andReturn
          hasDeprecations: true
          version: '<=1.0.0'
        pack = atom.packages.getLoadedPackage('package-with-config')
        card = new PackageCard(pack, packageManager)
        jasmine.attachToDOM(card[0])

      it "shows the correct state", ->
        expect(card.updateButtonGroup).not.toBeVisible()
        expect(card.installButtonGroup).not.toBeVisible()
        expect(card.installAlternativeButtonGroup).not.toBeVisible()

        expect(card).toHaveClass 'deprecated'
        expect(card.packageMessage.text()).toContain 'no update available'
        expect(card.packageMessage).toHaveClass 'text-warning'
        expect(card.settingsButton[0].disabled).toBe true
        expect(card.uninstallButton).toBeVisible()
        expect(card.enablementButton).toBeVisible()
        expect(card.enablementButton.text()).toBe 'Disable'

    describe "when hasDeprecations is true and there is an update is available", ->
      beforeEach ->
        spyOn(PackageCard::, 'isDeprecated').andCallFake (version) ->
          semver = require 'semver'
          semver.satisfies(version ? '1.0.0', '<=1.0.1')
        spyOn(PackageCard::, 'getPackageDeprecationMetadata').andReturn
          hasDeprecations: true
          version: '<=1.0.1'
        pack = atom.packages.getLoadedPackage('package-with-config')
        card = new PackageCard(pack, packageManager)
        jasmine.attachToDOM(card[0])

      it "explains that the update WILL fix the deprecations when the new version is higher than the max version", ->
        card.displayAvailableUpdate('1.1.0')
        expect(card.packageMessage.text()).not.toContain 'no update available'
        expect(card.packageMessage.text()).toContain 'without deprecations'

      it "explains that the update WILL NOT fix the deprecations when the new version isnt higher than the max version", ->
        card.displayAvailableUpdate('1.0.1')
        expect(card.packageMessage.text()).not.toContain 'no update available'
        expect(card.packageMessage.text()).toContain 'still contains deprecations'

    describe "when hasAlternative is true and alternative is core", ->
      beforeEach ->
        spyOn(PackageCard::, 'isDeprecated').andReturn true
        spyOn(PackageCard::, 'getPackageDeprecationMetadata').andReturn
          hasAlternative: true
          alternative: 'core'
        pack = atom.packages.getLoadedPackage('package-with-config')
        card = new PackageCard(pack, packageManager)
        jasmine.attachToDOM(card[0])

      it "notifies that the package has been replaced, shows uninstallButton", ->
        expect(card.updateButtonGroup).not.toBeVisible()
        expect(card.installButtonGroup).not.toBeVisible()
        expect(card.installAlternativeButtonGroup).not.toBeVisible()

        expect(card).toHaveClass 'deprecated'
        expect(card.packageMessage.text()).toContain 'have been added to core'
        expect(card.packageMessage).toHaveClass 'text-warning'
        expect(card.settingsButton).not.toBeVisible()
        expect(card.uninstallButton).toBeVisible()
        expect(card.enablementButton).not.toBeVisible()

    describe "when hasAlternative is true and alternative is a package that has not been installed", ->
      beforeEach ->
        spyOn(PackageCard::, 'isDeprecated').andReturn true
        spyOn(PackageCard::, 'getPackageDeprecationMetadata').andReturn
          hasAlternative: true
          alternative: 'not-installed-package'
        pack = atom.packages.getLoadedPackage('package-with-config')
        card = new PackageCard(pack, packageManager)
        jasmine.attachToDOM(card[0])

      it "notifies that the package has been replaced, shows uninstallButton", ->
        expect(card.updateButtonGroup).not.toBeVisible()
        expect(card.installButtonGroup).not.toBeVisible()
        expect(card.packageActionButtonGroup).not.toBeVisible()
        expect(card.installAlternativeButtonGroup).toBeVisible()

        expect(card).toHaveClass 'deprecated'
        expect(card.packageMessage.text()).toContain 'has been replaced by not-installed-package'
        expect(card.packageMessage).toHaveClass 'text-warning'

      it "uninstalls the old package, and installs the new when the install alternative button is clicked", ->
        [installCallback, uninstallCallback] = []
        packageManager.runCommand.andCallFake (args, callback) ->
          if args[0] is 'install'
            installCallback = callback
          else if args[0] is 'uninstall'
            uninstallCallback = callback
          onWillThrowError: ->

        spyOn(packageManager, 'install').andCallThrough()
        spyOn(packageManager, 'uninstall').andCallThrough()
        spyOn(atom.packages, 'activatePackage')

        card.installAlternativeButton.click()

        expect(card.installAlternativeButton[0].disabled).toBe(true)
        expect(card.installAlternativeButton).toHaveClass('is-installing')

        expect(packageManager.uninstall).toHaveBeenCalled()
        expect(packageManager.uninstall.mostRecentCall.args[0].name).toEqual('package-with-config')

        expect(packageManager.install).toHaveBeenCalled()
        expect(packageManager.install.mostRecentCall.args[0]).toEqual({name: 'not-installed-package'})

        uninstallCallback(0, '', '')

        waits 1
        runs ->
          expect(card.installAlternativeButton[0].disabled).toBe(true)
          expect(card.installAlternativeButton).toHaveClass('is-installing')
          installCallback(0, '', '')

        waits 1
        runs ->
          expect(card.installAlternativeButton[0].disabled).toBe(false)
          expect(card.installAlternativeButton).not.toHaveClass('is-installing')
          expect(card.updateButtonGroup).not.toBeVisible()
          expect(card.installButtonGroup).not.toBeVisible()
          expect(card.packageActionButtonGroup).not.toBeVisible()
          expect(card.installAlternativeButtonGroup).not.toBeVisible()

    describe "when hasAlternative is true and alternative is an installed package", ->
      beforeEach ->
        atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'language-test'))
        waitsFor ->
          atom.packages.isPackageLoaded('language-test') is true

        runs ->
          spyOn(PackageCard::, 'isDeprecated').andReturn true
          spyOn(PackageCard::, 'getPackageDeprecationMetadata').andReturn
            hasAlternative: true
            alternative: 'language-test'
          pack = atom.packages.getLoadedPackage('package-with-config')
          card = new PackageCard(pack, packageManager)
          jasmine.attachToDOM(card[0])

      it "notifies that the package has been replaced, shows uninstallButton", ->
        expect(card.updateButtonGroup).not.toBeVisible()
        expect(card.installButtonGroup).not.toBeVisible()
        expect(card.installAlternativeButtonGroup).not.toBeVisible()

        expect(card).toHaveClass 'deprecated'
        expect(card.packageMessage.text()).toContain 'has been replaced by language-test'
        expect(card.packageMessage.text()).toContain 'already installed'
        expect(card.packageMessage.text()).toContain 'Please uninstall'
        expect(card.packageMessage).toHaveClass 'text-warning'
        expect(card.settingsButton).not.toBeVisible()
        expect(card.uninstallButton).toBeVisible()
        expect(card.enablementButton).not.toBeVisible()
