AvailablePackageView = require '../lib/available-package-view'

describe "AvailablePackageView", ->
  setPackageStatusSpies = (opts) ->
    spyOn(AvailablePackageView.prototype, 'isInstalled').andReturn(opts.installed)
    spyOn(AvailablePackageView.prototype, 'isDisabled').andReturn(opts.disabled)


  beforeEach ->
    @packageManager = jasmine.createSpyObj('packageManager', ['on', 'getClient', 'emit', 'install', 'uninstall'])
    @packageManager.getClient.andCallFake -> jasmine.createSpyObj('client', ['avatar', 'package'])

  it "doesn't show the disable control for a theme", ->
    setPackageStatusSpies {installed: true, disabled: false}
    view = new AvailablePackageView {theme: 'syntax', name: 'test-theme'}, @packageManager
    expect(view.enablementButton.css('display')).toBe('none')

  it "can be disabled if installed", ->
    setPackageStatusSpies {installed: true, disabled: false}
    spyOn(atom.packages, 'disablePackage').andReturn(true)

    view = new AvailablePackageView {name: 'test-package'}, @packageManager
    expect(view.enablementButton.find('.disable-text').text()).toBe('Disable')
    view.enablementButton.click()
    expect(atom.packages.disablePackage).toHaveBeenCalled()

  it "can be uninstalled if installed", ->
    setPackageStatusSpies {installed: true, disabled: false}

    view = new AvailablePackageView {name: 'test-package'}, @packageManager
    expect(view.uninstallButton.css('display')).not.toBe('none')
    view.uninstallButton.click()
    expect(@packageManager.uninstall).toHaveBeenCalled()

  it "can be installed if currently not installed", ->
    setPackageStatusSpies {installed: false, disabled: false}

    view = new AvailablePackageView {name: 'test-package'}, @packageManager
    expect(view.installButton.css('display')).not.toBe('none')
    expect(view.uninstallButton.css('display')).toBe('none')
    view.installButton.click()
    expect(@packageManager.install).toHaveBeenCalled()
