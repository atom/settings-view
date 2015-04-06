PackageCard = require '../lib/package-card'

describe "PackageCard", ->
  setPackageStatusSpies = (opts) ->
    spyOn(PackageCard.prototype, 'isInstalled').andReturn(opts.installed)
    spyOn(PackageCard.prototype, 'isDisabled').andReturn(opts.disabled)
    spyOn(PackageCard.prototype, 'hasSettings').andReturn(opts.hasSettings)


  beforeEach ->
    @packageManager = jasmine.createSpyObj('packageManager', ['on', 'getClient', 'emit', 'install', 'uninstall'])
    @packageManager.getClient.andCallFake -> jasmine.createSpyObj('client', ['avatar', 'package'])

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

  it "removes the settings button if a package has no settings", ->
    setPackageStatusSpies {installed: true, disabled: false, hasSettings: false}
    view = new PackageCard {name: 'test-package'}, @packageManager
    expect(view.find.settingsButton).not.toExist()
