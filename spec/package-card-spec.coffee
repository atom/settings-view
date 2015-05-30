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

    describe "when hasAlternative is true alternative is core", ->
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
