PackageManager = require '../lib/package-manager'
PackageCard = require '../lib/package-card'

describe "PackageCard", ->
  setPackageStatusSpies = (opts) ->
    spyOn(PackageCard.prototype, 'isInstalled').andReturn(opts.installed)
    spyOn(PackageCard.prototype, 'isDisabled').andReturn(opts.disabled)
    spyOn(PackageCard.prototype, 'hasSettings').andReturn(opts.hasSettings)

  beforeEach ->
    @packageManager = jasmine.createSpyObj('packageManager', ['on', 'getClient', 'emit', 'install', 'uninstall', 'loadCompatiblePackageVersion', 'satisfiesVersion', 'normalizeVersion'])
    @packageManager.normalizeVersion.andCallFake ->
      PackageManager.prototype.normalizeVersion(arguments...)
    @packageManager.satisfiesVersion.andCallFake ->
      PackageManager.prototype.satisfiesVersion(arguments...)
    @packageManager.getClient.andCallFake -> jasmine.createSpyObj('client', ['avatar', 'package'])
    @packageManager.loadCompatiblePackageVersion.andCallFake (packageName, callback) ->
      pack =
        name: packageName
        version: '0.1.0'
        engines:
          atom: '>0.50.0'

      callback(null, pack)

  it "doesn't show the disable control for a theme", ->
    setPackageStatusSpies {installed: true, disabled: false}
    view = new PackageCard {theme: 'syntax', name: 'test-theme'}, @packageManager
    expect(view.find.enablementButton).not.toExist()

  it "doesn't show the status indicator for a theme", ->
    setPackageStatusSpies {installed: true, disabled: false}
    view = new PackageCard {theme: 'syntax', name: 'test-theme'}, @packageManager
    expect(view.find.statusIndicatorButton).not.toExist()

  it "doesn't show the settings button for a theme", ->
    setPackageStatusSpies {installed: true, disabled: false}
    view = new PackageCard {theme: 'syntax', name: 'test-theme'}, @packageManager
    expect(view.find.settingsButton).not.toExist()

  it "can be disabled if installed", ->
    setPackageStatusSpies {installed: true, disabled: false}
    spyOn(atom.packages, 'disablePackage').andReturn(true)

    view = new PackageCard {name: 'test-package'}, @packageManager
    expect(view.enablementButton.find('.disable-text').text()).toBe('Disable')
    view.enablementButton.click()
    expect(atom.packages.disablePackage).toHaveBeenCalled()

  it "can be uninstalled if installed", ->
    setPackageStatusSpies {installed: true, disabled: false}

    view = new PackageCard {name: 'test-package'}, @packageManager
    expect(view.uninstallButton.css('display')).not.toBe('none')
    view.uninstallButton.click()
    expect(@packageManager.uninstall).toHaveBeenCalled()

  it "can be installed if currently not installed", ->
    setPackageStatusSpies {installed: false, disabled: false}

    view = new PackageCard {name: 'test-package'}, @packageManager
    expect(view.installButton.css('display')).not.toBe('none')
    expect(view.uninstallButton.css('display')).toBe('none')
    view.installButton.click()
    expect(@packageManager.install).toHaveBeenCalled()

  it "can be installed if currently not installed and package latest release engine match atom version", ->
    @packageManager.loadCompatiblePackageVersion.andCallFake (packageName, callback) ->
      pack =
        name: packageName
        version: '0.1.0'
        engines:
          atom: '>0.50.0'

      callback(null, pack)

    setPackageStatusSpies {installed: false, disabled: false}

    view = new PackageCard {
      name: 'test-package'
      version: '0.1.0'
      engines:
        atom: '>0.50.0'
    }, @packageManager

    # In that case there's no need to make a request to get all the versions
    expect(@packageManager.loadCompatiblePackageVersion).not.toHaveBeenCalled()

    expect(view.installButton.css('display')).not.toBe('none')
    expect(view.uninstallButton.css('display')).toBe('none')
    view.installButton.click()
    expect(@packageManager.install).toHaveBeenCalled()
    expect(@packageManager.install.mostRecentCall.args[0]).toEqual({
      name: 'test-package'
      version: '0.1.0'
      engines:
        atom: '>0.50.0'
    })

  it "can be installed with a previous version whose engine match the current atom version", ->
    @packageManager.loadCompatiblePackageVersion.andCallFake (packageName, callback) ->
      pack =
        name: packageName
        version: '0.0.1'
        engines:
          atom: '>0.50.0'

      callback(null, pack)

    setPackageStatusSpies {installed: false, disabled: false}

    view = new PackageCard {
      name: 'test-package'
      version: '0.1.0'
      engines:
        atom: '>99.0.0'
    }, @packageManager

    expect(view.installButton.css('display')).not.toBe('none')
    expect(view.uninstallButton.css('display')).toBe('none')
    expect(view.versionValue.text()).toBe('0.0.1')
    expect(view.versionValue).toHaveClass('text-warning')
    expect(view.packageMessage).toHaveClass('text-warning')
    view.installButton.click()
    expect(@packageManager.install).toHaveBeenCalled()
    expect(@packageManager.install.mostRecentCall.args[0]).toEqual({
      name: 'test-package'
      version: '0.0.1'
      engines:
        atom: '>0.50.0'
    })

  it "can't be installed if there is no version compatible with the current atom version", ->
    @packageManager.loadCompatiblePackageVersion.andCallFake (packageName, callback) ->
      pack =
        name: packageName

      callback(null, pack)

    setPackageStatusSpies {installed: false, disabled: false}

    view = new PackageCard {
      name: 'test-package'
      engines:
        atom: '>=99.0.0'
    }, @packageManager

    expect(view.installButton.css('display')).toBe('none')
    expect(view.uninstallButton.css('display')).toBe('none')
    expect(view.settingsButton.css('display')).toBe('none')
    expect(view.enablementButton.css('display')).toBe('none')
    expect(view.versionValue).toHaveClass('text-danger')
    expect(view.packageMessage).toHaveClass('text-danger')

  it "removes the settings button if a package has no settings", ->
    setPackageStatusSpies {installed: true, disabled: false, hasSettings: false}
    view = new PackageCard {name: 'test-package'}, @packageManager
    expect(view.find.settingsButton).not.toExist()
