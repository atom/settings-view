path = require 'path'
PackageCard = require '../lib/package-card'
PackageManager = require '../lib/package-manager'

describe "PackageCard", ->
  setPackageStatusSpies = (opts) ->
    spyOn(PackageCard.prototype, 'isInstalled').andReturn(opts.installed)
    spyOn(PackageCard.prototype, 'isDisabled').andReturn(opts.disabled)
    spyOn(PackageCard.prototype, 'hasSettings').andReturn(opts.hasSettings)

  [card, packageManager] = []

  beforeEach ->
    packageManager = new PackageManager()
    spyOn(packageManager, 'runCommand')

  it "doesn't show the disable control for a theme", ->
    setPackageStatusSpies {installed: true, disabled: false}
    card = new PackageCard({theme: 'syntax', name: 'test-theme'}, packageManager)
    jasmine.attachToDOM(card[0])
    expect(card.enablementButton).not.toBeVisible()

  it "doesn't show the status indicator for a theme", ->
    setPackageStatusSpies {installed: true, disabled: false}
    card = new PackageCard {theme: 'syntax', name: 'test-theme'}, packageManager
    jasmine.attachToDOM(card[0])
    expect(card.statusIndicatorButton).not.toBeVisible()

  it "doesn't show the settings button for a theme", ->
    setPackageStatusSpies {installed: true, disabled: false}
    card = new PackageCard {theme: 'syntax', name: 'test-theme'}, packageManager
    jasmine.attachToDOM(card[0])
    expect(card.settingsButton).not.toBeVisible()

  it "removes the settings button if a package has no settings", ->
    setPackageStatusSpies {installed: true, disabled: false, hasSettings: false}
    card = new PackageCard {name: 'test-package'}, packageManager
    jasmine.attachToDOM(card[0])
    expect(card.settingsButton).not.toBeVisible()

  it "removes the uninstall button if a package has is a bundled package", ->
    setPackageStatusSpies {installed: true, disabled: false, hasSettings: true}
    card = new PackageCard {name: 'find-and-replace'}, packageManager
    jasmine.attachToDOM(card[0])
    expect(card.uninstallButton).not.toBeVisible()

  it "displays the new version in the update button", ->
    setPackageStatusSpies {installed: true, disabled: false, hasSettings: true}
    card = new PackageCard {name: 'find-and-replace', version: '1.0.0', latestVersion: '1.2.0'}, packageManager
    jasmine.attachToDOM(card[0])
    expect(card.updateButton).toBeVisible()
    expect(card.updateButton.text()).toContain 'Update to 1.2.0'

  it "displays the new version in the update button when the package is disabled", ->
    setPackageStatusSpies {installed: true, disabled: true, hasSettings: true}
    card = new PackageCard {name: 'find-and-replace', version: '1.0.0', latestVersion: '1.2.0'}, packageManager
    jasmine.attachToDOM(card[0])
    expect(card.updateButton).toBeVisible()
    expect(card.updateButton.text()).toContain 'Update to 1.2.0'

  it "shows the author details", ->
    authorName = "authorName"
    pack =
      name: 'some-package'
      version: '0.1.0'
      repository: "https://github.com/#{authorName}/some-package"
    card = new PackageCard(pack, packageManager)

    jasmine.attachToDOM(card[0])

    expect(card.loginLink.text()).toBe(authorName)
    expect(card.loginLink.attr("href")).toBe("https://atom.io/users/#{authorName}")

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

    it "can be installed if currently not installed", ->
      setPackageStatusSpies {installed: false, disabled: false}
      spyOn(packageManager, 'install')

      card = new PackageCard {name: 'test-package'}, packageManager
      expect(card.installButton.css('display')).not.toBe('none')
      expect(card.uninstallButton.css('display')).toBe('none')
      card.installButton.click()
      expect(packageManager.install).toHaveBeenCalled()

    it "can be installed if currently not installed and package latest release engine match atom version", ->
      spyOn(packageManager, 'install')
      spyOn(packageManager, 'loadCompatiblePackageVersion').andCallFake (packageName, callback) ->
        pack =
          name: packageName
          version: '0.1.0'
          engines:
            atom: '>0.50.0'

        callback(null, pack)

      setPackageStatusSpies {installed: false, disabled: false}

      card = new PackageCard {
        name: 'test-package'
        version: '0.1.0'
        engines:
          atom: '>0.50.0'
      }, packageManager

      # In that case there's no need to make a request to get all the versions
      expect(packageManager.loadCompatiblePackageVersion).not.toHaveBeenCalled()

      expect(card.installButton.css('display')).not.toBe('none')
      expect(card.uninstallButton.css('display')).toBe('none')
      card.installButton.click()
      expect(packageManager.install).toHaveBeenCalled()
      expect(packageManager.install.mostRecentCall.args[0]).toEqual({
        name: 'test-package'
        version: '0.1.0'
        engines:
          atom: '>0.50.0'
      })

    it "can be installed with a previous version whose engine match the current atom version", ->
      spyOn(packageManager, 'install')
      spyOn(packageManager, 'loadCompatiblePackageVersion').andCallFake (packageName, callback) ->
        pack =
          name: packageName
          version: '0.0.1'
          engines:
            atom: '>0.50.0'

        callback(null, pack)

      setPackageStatusSpies {installed: false, disabled: false}

      card = new PackageCard {
        name: 'test-package'
        version: '0.1.0'
        engines:
          atom: '>99.0.0'
      }, packageManager

      expect(card.installButton.css('display')).not.toBe('none')
      expect(card.uninstallButton.css('display')).toBe('none')
      expect(card.versionValue.text()).toBe('0.0.1')
      expect(card.versionValue).toHaveClass('text-warning')
      expect(card.packageMessage).toHaveClass('text-warning')
      card.installButton.click()
      expect(packageManager.install).toHaveBeenCalled()
      expect(packageManager.install.mostRecentCall.args[0]).toEqual({
        name: 'test-package'
        version: '0.0.1'
        engines:
          atom: '>0.50.0'
      })

    it "can't be installed if there is no version compatible with the current atom version", ->
      spyOn(packageManager, 'loadCompatiblePackageVersion').andCallFake (packageName, callback) ->
        pack =
          name: packageName

        callback(null, pack)

      setPackageStatusSpies {installed: false, disabled: false}

      pack =
        name: 'test-package'
        engines:
          atom: '>=99.0.0'
      card = new PackageCard(pack , packageManager)
      jasmine.attachToDOM(card[0])

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
      setPackageStatusSpies {installed: true, disabled: false}
      spyOn(atom.packages, 'disablePackage').andReturn(true)

      card = new PackageCard {name: 'test-package'}, packageManager
      expect(card.enablementButton.find('.disable-text').text()).toBe('Disable')
      card.enablementButton.click()
      expect(atom.packages.disablePackage).toHaveBeenCalled()

    it "will stay disabled after an update", ->
      pack = atom.packages.getLoadedPackage('package-with-config')
      pack.latestVersion = '1.1.0'
      packageUpdated = false

      packageManager.on 'package-updated', -> packageUpdated = true
      packageManager.runCommand.andCallFake (args, callback) ->
        callback(0, '', '')
        onWillThrowError: ->

      originalLoadPackage = atom.packages.loadPackage
      spyOn(atom.packages, 'loadPackage').andCallFake ->
        originalLoadPackage.call(atom.packages, path.join(__dirname, 'fixtures', 'package-with-config'))

      pack.disable()
      card = new PackageCard(pack, packageManager)
      expect(atom.packages.isPackageDisabled('package-with-config')).toBe true
      card.update()

      waitsFor ->
        packageUpdated

      runs ->
        expect(atom.packages.isPackageDisabled('package-with-config')).toBe true

    it "is uninstalled when the uninstallButton is clicked", ->
      setPackageStatusSpies {installed: true, disabled: false}

      [installCallback, uninstallCallback] = []
      packageManager.runCommand.andCallFake (args, callback) ->
        if args[0] is 'install'
          installCallback = callback
        else if args[0] is 'uninstall'
          uninstallCallback = callback
        onWillThrowError: ->

      spyOn(packageManager, 'install').andCallThrough()
      spyOn(packageManager, 'uninstall').andCallThrough()

      pack = atom.packages.getLoadedPackage('package-with-config')
      card = new PackageCard(pack, packageManager)
      jasmine.attachToDOM(card[0])

      expect(card.uninstallButton).toBeVisible()
      expect(card.enablementButton).toBeVisible()
      card.uninstallButton.click()

      expect(card.uninstallButton[0].disabled).toBe true
      expect(card.enablementButton[0].disabled).toBe true
      expect(card.uninstallButton).toHaveClass('is-uninstalling')

      expect(packageManager.uninstall).toHaveBeenCalled()
      expect(packageManager.uninstall.mostRecentCall.args[0].name).toEqual('package-with-config')

      jasmine.unspy(PackageCard::, 'isInstalled')
      spyOn(PackageCard.prototype, 'isInstalled').andReturn false
      uninstallCallback(0, '', '')

      waits 1
      runs ->
        expect(card.uninstallButton[0].disabled).toBe false
        expect(card.uninstallButton).not.toHaveClass('is-uninstalling')
        expect(card.installButtonGroup).toBeVisible()
        expect(card.updateButtonGroup).not.toBeVisible()
        expect(card.packageActionButtonGroup).not.toBeVisible()
        expect(card.installAlternativeButtonGroup).not.toBeVisible()

    it "shows the settings, uninstall, and enable buttons when disabled", ->
      atom.config.set('package-with-config.setting', 'something')
      pack = atom.packages.getLoadedPackage('package-with-config')
      spyOn(atom.packages, 'isPackageDisabled').andReturn(true)
      card = new PackageCard(pack, packageManager)
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
      spyOn(PackageCard::, 'hasSettings').andReturn(false)
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
        spyOn(PackageCard::, 'isDeprecated').andReturn true
        spyOn(PackageCard::, 'isInstalled').andReturn true
        spyOn(PackageCard::, 'getDeprecatedPackageMetadata').andReturn
          hasDeprecations: true
          version: '<=1.0.0'
        pack = atom.packages.getLoadedPackage('package-with-config')
        pack.version = pack.metadata.version
        card = new PackageCard(pack, packageManager)
        jasmine.attachToDOM(card[0])

      it "shows the correct state", ->
        spyOn(atom.packages, 'isPackageDisabled').andReturn false
        card.updateInterfaceState()
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
        spyOn(atom.packages, 'isPackageDisabled').andReturn true
        card.updateInterfaceState()
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
      beforeEach ->
        spyOn(PackageCard::, 'isDeprecated').andCallFake (version) ->
          semver = require 'semver'
          version = version ? card?.pack?.version ? '1.0.0'
          semver.satisfies(version, '<=1.0.1')
        spyOn(PackageCard::, 'getDeprecatedPackageMetadata').andReturn
          hasDeprecations: true
          version: '<=1.0.1'
        pack = atom.packages.getLoadedPackage('package-with-config')
        pack.version = pack.metadata.version
        card = new PackageCard(pack, packageManager)
        jasmine.attachToDOM(card[0])

      it "explains that the update WILL NOT fix the deprecations when the new version isnt higher than the max version", ->
        card.displayAvailableUpdate('1.0.1')
        expect(card.packageMessage.text()).not.toContain 'no update available'
        expect(card.packageMessage.text()).toContain 'still contains deprecations'

      describe "when the available update fixes deprecations", ->
        it "explains that the update WILL fix the deprecations when the new version is higher than the max version", ->
          card.displayAvailableUpdate('1.1.0')
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
          expect(atom.packages.getLoadedPackage('package-with-config')).toBeTruthy()

          [updateCallback] = []
          packageManager.runCommand.andCallFake (args, callback) ->
            updateCallback = callback
            onWillThrowError: ->
          spyOn(packageManager, 'update').andCallThrough()

          originalLoadPackage = atom.packages.loadPackage
          spyOn(atom.packages, 'loadPackage').andCallFake ->
            pack = originalLoadPackage.call(atom.packages, path.join(__dirname, 'fixtures', 'package-with-config'))
            pack.metadata.version = '1.1.0' if pack?
            pack

          card.displayAvailableUpdate('1.1.0')
          expect(card.updateButtonGroup).toBeVisible()

          expect(atom.packages.getLoadedPackage('package-with-config')).toBeTruthy()
          card.updateButton.click()

          expect(card.updateButton[0].disabled).toBe true
          expect(card.updateButton).toHaveClass 'is-installing'

          expect(packageManager.update).toHaveBeenCalled()
          expect(packageManager.update.mostRecentCall.args[0].name).toEqual 'package-with-config'
          expect(packageManager.runCommand).toHaveBeenCalled()
          expect(card).toHaveClass 'deprecated'

          expect(card.updateButtonGroup).toBeVisible()
          expect(card.installButtonGroup).not.toBeVisible()
          expect(card.installAlternativeButtonGroup).not.toBeVisible()

          updateCallback(0, '', '')

          waitsFor ->
            atom.packages.isPackageActive('package-with-config')

          runs ->
            expect(card.updateButton[0].disabled).toBe false
            expect(card.updateButton).not.toHaveClass 'is-installing'
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
        spyOn(atom.packages, 'isDeprecatedPackage').andReturn true
        spyOn(atom.packages, 'isPackageLoaded').andReturn false
        spyOn(atom.packages, 'isPackageDisabled').andReturn false
        spyOn(packageManager, 'getAvailablePackageNames').andReturn(['package-with-config'])
        spyOn(PackageCard::, 'getDeprecatedPackageMetadata').andReturn
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
        spyOn(PackageCard::, 'getDeprecatedPackageMetadata').andReturn
          hasAlternative: true
          alternative: 'not-installed-package'
        pack = atom.packages.getLoadedPackage('package-with-config')
        card = new PackageCard(pack, packageManager)
        jasmine.attachToDOM(card[0])

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
          spyOn(PackageCard::, 'getDeprecatedPackageMetadata').andReturn
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
