{mockedPackageManager} = require './spec-helper'

path = require 'path'
semver = require 'semver'
Package = require '../lib/package'
PackageCard = require '../lib/package-card'

describe "PackageCard", ->
  [card, authorName, pack, packageManager] = []

  beforeEach ->
    packageManager = mockedPackageManager()
    authorName = "author-of-test-package"
    pack = new Package {
      name: 'test-package'
      repository: "https://github.com/#{authorName}/some-package"
    }, packageManager
    spyOn(pack, 'isInstalled').andReturn(true)

    card = new PackageCard pack
    jasmine.attachToDOM(card[0])

  afterEach ->
    [card, authorName, pack, packageManager] = []

  describe "when it is a theme", ->
    beforeEach ->
      pack = new Package {name: 'test-theme', theme: 'ui'}, packageManager
      card = new PackageCard pack

      jasmine.attachToDOM(card[0])

    it "doesn't show the disable control for a theme", ->
      expect(card.enablementButton).not.toBeVisible()

    it "doesn't show the status indicator for a theme", ->
      expect(card.statusIndicatorButton).not.toBeVisible()

  it "shows the settings button if it has settings and is not on the settings view", ->
    spyOn(pack, 'hasSettings').andReturn(true)
    card.updateState()

    expect(card.settingsButton).toBeVisible()

  it "doesn't show the settings button on the settings view", ->
    spyOn(pack, 'hasSettings').andReturn(true)
    card.onSettingsView = true
    card.updateState()

    expect(card.settingsButton).not.toBeVisible()

  it "removes the settings button if a package has no settings", ->
    spyOn(pack, 'hasSettings').andReturn(false)
    card.updateState()

    expect(card.settingsButton).not.toBeVisible()

  it "shows an uninstall button if the package is installed", ->
    card.updateState()

    expect(card.uninstallButton).toBeVisible()

  it "removes the uninstall button if a package has is a bundled package", ->
    spyOn(pack, 'isBundled').andReturn(true)
    card = new PackageCard pack
    jasmine.attachToDOM(card[0])

    expect(card.uninstallButton).not.toBeVisible()

  describe "when a new version is available", ->
    beforeEach ->
      pack.version = '1.0.0'
      pack.latestVersion = '1.2.0'

      card.updateState()

    it "displays the new version in the update button", ->
      expect(card.updateButton).toBeVisible()
      expect(card.updateButton.text()).toContain 'Update to 1.2.0'

    it "displays the new version in the update button when the package is disabled", ->
      spyOn(pack, 'isDisabled').andReturn(true)
      card.updateState()

      expect(card.updateButton).toBeVisible()
      expect(card.updateButton.text()).toContain 'Update to 1.2.0'

  it "shows the author details", ->
    expect(card.loginLink.text()).toBe(authorName)
    expect(card.loginLink.attr("href")).toBe("https://atom.io/users/#{authorName}")

  describe "when the package is not installed", ->
    beforeEach ->
      jasmine.unspy(pack, 'isInstalled')
      spyOn(pack, "isInstalled").andReturn(false)
      card.updateState()

    it "does not show the settings, uninstall, and disable buttons", ->
      expect(card.installButtonGroup).toBeVisible()
      expect(card.updateButtonGroup).not.toBeVisible()
      expect(card.installAlternativeButton).not.toBeVisible()
      expect(card.packageActionButtonGroup).not.toBeVisible()

    it "can be installed if currently not installed", ->
      spyOn(card.package, 'install')

      expect(card.installButton).toBeVisible()
      expect(card.uninstallButton).not.toBeVisible()

      card.installButton.click()
      expect(card.package.install).toHaveBeenCalled()

    it "can not be installed if it is not compatible", ->
      spyOn(pack, "isCompatible").andReturn(false)
      card.updateState()

      expect(card.installButton).not.toBeVisible()

    it "can be installed if currently not installed and package is compatible", ->
      pack = new Package {
        name: 'test-package'
        version: '0.1.0'
        engines:
          atom: '>0.50.0'
      }, packageManager
      spyOn(pack, 'isInstalled').andReturn(false)
      spyOn(pack, 'isDisabled').andReturn(false)
      spyOn(pack, 'isCompatible').andReturn(true)
      spyOn(pack, 'install')

      spyOn(pack, 'loadCompatibleVersion')
      card = new PackageCard pack

      expect(pack.loadCompatibleVersion).not.toHaveBeenCalled()
      expect(card.installButton.css('display')).not.toBe('none')
      expect(card.uninstallButton.css('display')).toBe('none')

      card.installButton.click()
      expect(pack.install).toHaveBeenCalled()

    it "can be installed with a previous version whose engine match the current atom version", ->
      compatiblePack = new Package {
        name: 'test-package'
        version: '0.0.1'
        engines:
          atom: '>0.50.0'
      }, packageManager

      spyOn(compatiblePack, 'install')

      pack = new Package {
        name: 'test-package'
        version: '0.1.0'
        engines:
          atom: '>99.0.0'
      }, packageManager
      spyOn(pack, 'isInstalled').andReturn(false)
      spyOn(pack, 'isDisabled').andReturn(false)
      spyOn(pack, 'isCompatible').andReturn(false)
      spyOn(pack, 'loadCompatibleVersion').andCallFake ->
        Promise.resolve(compatiblePack)

      card = new PackageCard pack
      jasmine.attachToDOM(card[0])

      waitsFor ->
        card.versionValue.text() is '0.0.1'

      runs ->
        expect(pack.loadCompatibleVersion).toHaveBeenCalled()
        expect(card.installButton).toBeVisible()
        expect(card.uninstallButton).not.toBeVisible()
        expect(card.versionValue.text()).toBe('0.0.1')
        expect(card.versionValue).toHaveClass('text-warning')
        expect(card.packageMessage).toHaveClass('text-warning')
        card.installButton.click()

        expect(compatiblePack.install).toHaveBeenCalled()

    it "can't be installed if there is no version compatible with the current atom version", ->
      runs ->
        pack = new Package {
          name: 'test-package'
          engines:
            atom: '>=99.0.0'
        }, packageManager
        spyOn(pack, 'isInstalled').andReturn(false)
        spyOn(pack, 'isDisabled').andReturn(false)
        spyOn(pack, 'isCompatible').andReturn(false)
        spyOn(pack, 'loadCompatibleVersion').andReturn Promise.resolve()
        card = new PackageCard pack
        jasmine.attachToDOM(card[0])

      waitsFor ->
        card.compatiblePack is false

      runs ->
        expect(pack.loadCompatibleVersion).toHaveBeenCalled()
        expect(card.installButtonGroup).not.toBeVisible()
        expect(card.packageActionButtonGroup).not.toBeVisible()
        expect(card.versionValue).toHaveClass('text-error')
        expect(card.packageMessage).toHaveClass('text-error')

  describe "when the package is installed", ->
    beforeEach ->
      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))

      waitsFor ->
        atom.packages.isPackageLoaded('package-with-config') is true

    it "can be disabled if installed", ->
      pack = new Package {name: 'test-package'}, packageManager
      spyOn(pack, 'isInstalled').andReturn(true)
      spyOn(pack, 'isDisabled').andReturn(false)
      spyOn(pack, 'disable').andReturn(true)
      card = new PackageCard pack

      expect(card.enablementButton.find('.disable-text').text()).toBe('Disable')
      card.enablementButton.click()
      expect(pack.disable).toHaveBeenCalled()

    it "shows the settings, uninstall, and enable buttons when disabled", ->
      atom.config.set('package-with-config.setting', 'something')
      pack = atom.packages.getLoadedPackage('package-with-config')
      pack = new Package pack, packageManager
      spyOn(pack, 'isDisabled').andReturn(true)
      spyOn(pack, 'isInstalled').andReturn(true)
      card = new PackageCard pack
      jasmine.attachToDOM(card[0])

      expect(card.updateButtonGroup).not.toBeVisible()
      expect(card.installButtonGroup).not.toBeVisible()
      expect(card.installAlternativeButtonGroup).not.toBeVisible()

      expect(card.settingsButton).toBeVisible()
      expect(card.uninstallButton).toBeVisible()
      expect(card.enablementButton).toBeVisible()
      expect(card.enablementButton.text()).toBe 'Enable'

    it "shows the settings, uninstall, and disable buttons", ->
      atom.config.set('package-with-config.setting', 'something')
      pack = atom.packages.getLoadedPackage('package-with-config')
      pack = new Package pack, packageManager
      spyOn(pack, 'isInstalled').andReturn(true)
      spyOn(pack, 'isDeprecated').andReturn(false)
      card = new PackageCard pack
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
      pack = new Package pack, packageManager
      spyOn(pack, 'isDeprecated').andReturn(false)
      spyOn(pack, 'isInstalled').andReturn(true)
      spyOn(pack, 'hasSettings').andReturn(false)
      card = new PackageCard pack
      jasmine.attachToDOM(card[0])

      expect(card.settingsButton).not.toBeVisible()
      expect(card.uninstallButton).toBeVisible()
      expect(card.enablementButton).toBeVisible()
      expect(card.enablementButton.text()).toBe 'Disable'


  #   # TODO this belongs into the specs of Package and/or PackageManager
  #   # it "will stay disabled after an update", ->
  #   #   pack = atom.packages.getLoadedPackage('package-with-config')
  #   #   pack.latestVersion = '1.1.0'
  #   #   packageUpdated = false
  #   #
  #   #   packageManager.on 'package-updated', -> packageUpdated = true
  #   #   packageManager.runCommand.andCallFake (args, callback) ->
  #   #     callback(0, '', '')
  #   #     onWillThrowError: ->
  #   #
  #   #   originalLoadPackage = atom.packages.loadPackage
  #   #   spyOn(atom.packages, 'loadPackage').andCallFake ->
  #   #     originalLoadPackage.call(atom.packages, path.join(__dirname, 'fixtures', 'package-with-config'))
  #   #
  #   #   pack.disable()
  #   #   card = new PackageCard(pack, packageManager)
  #   #   expect(atom.packages.isPackageDisabled('package-with-config')).toBe true
  #   #   card.update()
  #   #
  #   #   waitsFor ->
  #   #     packageUpdated
  #   #
  #   #   runs ->
  #   #     expect(atom.packages.isPackageDisabled('package-with-config')).toBe true
  #
  #   # it "is uninstalled when the uninstallButton is clicked", ->
  #   #   setPackageStatusSpies {installed: true, disabled: false}
  #   #
  #   #   [installCallback, uninstallCallback] = []
  #   #   packageManager.runCommand.andCallFake (args, callback) ->
  #   #     if args[0] is 'install'
  #   #       installCallback = callback
  #   #     else if args[0] is 'uninstall'
  #   #       uninstallCallback = callback
  #   #     onWillThrowError: ->
  #   #
  #   #   spyOn(packageManager, 'install').andCallThrough()
  #   #   spyOn(packageManager, 'uninstall').andCallThrough()
  #   #
  #   #   pack = atom.packages.getLoadedPackage('package-with-config')
  #   #   card = new PackageCard(pack, packageManager)
  #   #   jasmine.attachToDOM(card[0])
  #   #
  #   #   expect(card.uninstallButton).toBeVisible()
  #   #   expect(card.enablementButton).toBeVisible()
  #   #   card.uninstallButton.click()
  #   #
  #   #   expect(card.uninstallButton[0].disabled).toBe true
  #   #   expect(card.enablementButton[0].disabled).toBe true
  #   #   expect(card.uninstallButton).toHaveClass('is-uninstalling')
  #   #
  #   #   expect(packageManager.uninstall).toHaveBeenCalled()
  #   #   expect(packageManager.uninstall.mostRecentCall.args[0].name).toEqual('package-with-config')
  #   #
  #   #   jasmine.unspy(PackageCard::, 'isInstalled')
  #   #   spyOn(PackageCard.prototype, 'isInstalled').andReturn false
  #   #   uninstallCallback(0, '', '')
  #   #
  #   #   waits 1
  #   #   runs ->
  #   #     expect(card.uninstallButton[0].disabled).toBe false
  #   #     expect(card.uninstallButton).not.toHaveClass('is-uninstalling')
  #   #     expect(card.installButtonGroup).toBeVisible()
  #   #     expect(card.updateButtonGroup).not.toBeVisible()
  #   #     expect(card.packageActionButtonGroup).not.toBeVisible()
  #   #     expect(card.installAlternativeButtonGroup).not.toBeVisible()
  #

  describe "when the package has deprecations", ->
    beforeEach ->
      atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))

      waitsFor ->
        atom.packages.isPackageLoaded('package-with-config') is true

      runs ->
        atom.config.set('package-with-config.setting', 'something')

    describe "when hasDeprecations is true and NO update is available", ->
      beforeEach ->
        pack = atom.packages.getLoadedPackage('package-with-config')
        pack = new Package pack, packageManager
        spyOn(pack, 'isDeprecated').andReturn true
        spyOn(pack, 'isInstalled').andReturn true
        spyOn(pack, 'getDeprecatedMetadata').andReturn
          hasDeprecations: true
          version: '<=1.0.0'
        pack.version = pack.metadata.version
        card = new PackageCard pack
        jasmine.attachToDOM(card[0])

      it "shows the correct state", ->
        spyOn(pack, 'isDisabled').andReturn false
        card.updateState()
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
        expect(card.enablementButton.prop('disabled')).toBe false

      it "displays a disabled enable button when the package is disabled", ->
        spyOn(pack, 'isDisabled').andReturn true
        card.updateState()
        expect(card.updateButtonGroup).not.toBeVisible()
        expect(card.installButtonGroup).not.toBeVisible()
        expect(card.installAlternativeButtonGroup).not.toBeVisible()

        expect(card).toHaveClass 'deprecated'
        expect(card.packageMessage.text()).toContain 'no update available'
        expect(card.packageMessage).toHaveClass 'text-warning'
        expect(card.settingsButton[0].disabled).toBe true
        expect(card.uninstallButton).toBeVisible()
        expect(card.enablementButton).toBeVisible()
        expect(card.enablementButton.text()).toBe 'Enable'
        expect(card.enablementButton.prop('disabled')).toBe true

    # NOTE: the mocking here is pretty delicate
    describe "when hasDeprecations is true and there is an update is available", ->
      [newPack] = []

      beforeEach ->
        newPack = new Package {
          name: pack.name
          version: '1.1.0'
        }, packageManager

        pack.version = '1.0.0'

        pack.latestVersion = '1.1.0'
        spyOn(pack, 'isDeprecated').andCallFake ->
          pack.version is '1.0.0'

        spyOn(pack, 'newerPackage').andReturn newPack
        spyOn(pack, 'getDeprecatedMetadata').andReturn {
          hasDeprecations: true
        }

        card.updateState()

      it "explains that the update WILL NOT fix the deprecations when the new version isnt higher than the max version", ->
        spyOn(newPack, 'hasDeprecations').andReturn true
        card.updateState()

        expect(card.packageMessage.text()).not.toContain 'no update available'
        expect(card.packageMessage.text()).toContain 'still contains deprecations'

      describe "when the available update fixes deprecations", ->
        it "explains that the update WILL fix the deprecations when the new version is higher than the max version", ->
          spyOn(newPack, 'hasDeprecations').andReturn false
          card.updateState()

          expect(card.packageMessage.text()).not.toContain 'no update available'
          expect(card.packageMessage.text()).toContain 'without deprecations'

          expect(card.updateButtonGroup).toBeVisible()
          expect(card.installButtonGroup).not.toBeVisible()
          expect(card.packageActionButtonGroup).toBeVisible()
          expect(card.installAlternativeButtonGroup).not.toBeVisible()
          expect(card.uninstallButton).toBeVisible()
          expect(card.enablementButton).toBeVisible()
          expect(card.enablementButton.text()).toBe 'Disable'

        it "updates the package when the update button is clicked", ->
          runs ->
            spyOn(pack, 'update').andCallThrough()
            spyOn(card.updateButton, 'prop').andCallThrough()
            spyOn(card.updateButton, 'addClass').andCallThrough()
            spyOn(card.updateButton, 'removeClass').andCallThrough()

            jasmine.unspy(pack, 'isInstalled')
            spyOn(pack, 'isInstalled').andReturn(true)

            expect(atom.packages.getLoadedPackage('package-with-config')).toBeTruthy()

            expect(card).toHaveClass 'deprecated'
            expect(card.updateButtonGroup).toBeVisible()
            expect(card.installButtonGroup).not.toBeVisible()
            expect(card.installAlternativeButtonGroup).not.toBeVisible()

            card.updateButton.click()

          waitsFor ->
            card.updateButton.prop.callCount >= 1

          runs ->
            expect(pack.update).toHaveBeenCalled()
            expect(card.updateButton.prop).toHaveBeenCalledWith('disabled', true)
            expect(card.updateButton.addClass).toHaveBeenCalledWith('is-installing')
            expect(packageManager.command).toHaveBeenCalled()

          waitsFor ->
            pack.version is '1.1.0'

          runs ->
            expect(card.updateButton.prop).toHaveBeenCalledWith('disabled', false)
            expect(card.updateButton.removeClass).toHaveBeenCalledWith('is-installing')
            expect(card.updateButtonGroup).not.toBeVisible()
            expect(card.installButtonGroup).not.toBeVisible()
            expect(card.packageActionButtonGroup).toBeVisible()
            expect(card.installAlternativeButtonGroup).not.toBeVisible()

            expect(card).not.toHaveClass 'deprecated'
            expect(card.packageMessage).not.toHaveClass 'text-warning'
            expect(card.packageMessage.text()).toBe ''
            expect(card.versionValue.text()).toBe '1.1.0'

    describe "when hasAlternative is true and alternative is core", ->
      beforeEach ->
        spyOn(pack, 'isDeprecated').andCallFake -> true
        spyOn(pack, 'isDisabled').andCallFake -> false
        spyOn(pack, 'getDeprecatedMetadata').andReturn
          hasAlternative: true
          alternative: 'core'

        card.updateState()

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
        spyOn(pack, 'isDeprecated').andCallFake -> true
        spyOn(pack, 'getDeprecatedMetadata').andReturn
          hasAlternative: true
          alternative: 'not-installed-package'

        card.updateState()

      it "shows installAlternativeButton and uninstallButton", ->
        expect(card.updateButtonGroup).not.toBeVisible()
        expect(card.installButtonGroup).not.toBeVisible()
        expect(card.installAlternativeButtonGroup).toBeVisible()

        expect(card.packageActionButtonGroup).toBeVisible()
        expect(card.settingsButton).not.toBeVisible()
        expect(card.uninstallButton).toBeVisible()
        expect(card.enablementButton).not.toBeVisible()

        expect(card).toHaveClass 'deprecated'
        expect(card.packageMessage.text()).toContain 'has been replaced by not-installed-package'
        expect(card.packageMessage).toHaveClass 'text-warning'

      it "uninstalls the old package, and installs the new when the install alternative button is clicked", ->
        runs ->
          jasmine.unspy(pack, 'isInstalled')
          packageManager.addPackage(pack)
          spyOn(atom.packages, 'activatePackage').andCallThrough()
          spyOn(card.installAlternativeButton, 'prop').andCallThrough()
          card.installAlternativeButton.click()

        waitsFor ->
          packageManager.install.callCount >= 1

        runs ->
          expect(card.installAlternativeButton[0].disabled).toBe(true)
          expect(card.installAlternativeButton).toHaveClass('is-installing')

        waitsFor ->
          packageManager.uninstall.callCount >= 1

        runs ->
          expect(packageManager.uninstall).toHaveBeenCalled()
          expect(packageManager.install).toHaveBeenCalled()
          expect(card.installAlternativeButton[0].disabled).toBe(true)
          expect(card.installAlternativeButton).toHaveClass('is-installing')

        waitsFor ->
          card.installAlternativeButton.prop.callCount >= 2

        runs ->
          expect(card.installAlternativeButton[0].disabled).toBe(false)
          expect(card.installAlternativeButton).not.toHaveClass('is-installing')
          expect(card.updateButtonGroup).not.toBeVisible()
          expect(card.installButtonGroup).not.toBeVisible()
          expect(card.packageActionButtonGroup).not.toBeVisible()
          expect(card.installAlternativeButtonGroup).not.toBeVisible()

    describe "when hasAlternative is true and alternative is an installed package", ->
      beforeEach ->
        alternativePack = new Package {
          name: 'language-test'
          version: '1.1.0'
        }, packageManager
        spyOn(alternativePack, 'isInstalled').andReturn true

        spyOn(pack, 'isDeprecated').andReturn true
        spyOn(pack, 'getDeprecatedMetadata').andReturn
          hasAlternative: true
          alternative: 'language-test'
        spyOn(pack, 'alternative').andReturn alternativePack

        card.updateState()

      it "notifies that the package has been replaced, shows uninstallButton", ->
        expect(card.updateButtonGroup).not.toBeVisible()
        expect(card.installButtonGroup).not.toBeVisible()
        expect(card.installAlternativeButton).not.toBeVisible()

        expect(card).toHaveClass 'deprecated'
        expect(card.packageMessage.text()).toContain 'has been replaced by language-test'
        expect(card.packageMessage.text()).toContain 'already installed'
        expect(card.packageMessage.text()).toContain 'Please uninstall'
        expect(card.packageMessage).toHaveClass 'text-warning'
        expect(card.settingsButton).not.toBeVisible()
        expect(card.uninstallButton).toBeVisible()
        expect(card.enablementButton).not.toBeVisible()
