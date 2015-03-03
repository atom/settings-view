AvailablePackageView = require '../lib/available-package-view'
PackageManager = require '../lib/package-manager'

describe "AvailablePackageView", ->
  setPackageStatusSpies = (opts) ->
    spyOn(AvailablePackageView.prototype, 'isInstalled').andReturn(opts.installed)
    spyOn(AvailablePackageView.prototype, 'isDisabled').andReturn(opts.disabled)


  beforeEach ->
    @packageManager = jasmine.createSpyObj('packageManager', ['on', 'getClient', 'emit', 'install', 'uninstall', 'requestPackage', 'getLatestCompatibleVersion'])
    @packageManager.getLatestCompatibleVersion.andCallFake ->
      PackageManager.prototype.getLatestCompatibleVersion(arguments...)
    @packageManager.getClient.andCallFake -> jasmine.createSpyObj('client', ['avatar', 'package'])
    @packageManager.requestPackage.andCallFake (packageName, callback) ->
      pack =
        name: packageName
        releases:
          latest: '0.1.0'
        versions:
          '0.1.0':
            engines:
              atom: '>0.50.0'

      callback(null, pack)

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

  it "can be installed if currently not installed and package latest release engine match atom version", ->
    @packageManager.requestPackage.andCallFake (packageName, callback) ->
      pack =
        name: packageName
        releases:
          latest: '0.1.0'
        versions:
          '0.0.1':
            name: packageName
            version: '0.0.1'
            engines:
              atom: '>0.0.0'
          '0.1.0':
            name: packageName
            version: '0.1.0'
            engines:
              atom: '>0.50.0'

      callback(null, pack)

    setPackageStatusSpies {installed: false, disabled: false}

    view = new AvailablePackageView {
      name: 'test-package'
      version: '0.1.0'
      engines:
        atom: '>0.50.0'
    }, @packageManager

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
    @packageManager.requestPackage.andCallFake (packageName, callback) ->
      pack =
        name: packageName
        releases:
          latest: '0.1.0'
        versions:
          '0.0.1':
            name: packageName
            version: '0.0.1'
            engines:
              atom: '>0.50.0'
          '0.1.0':
            name: packageName
            version: '0.0.1'
            engines:
              atom: '>99.0.0'

      callback(null, pack)

    setPackageStatusSpies {installed: false, disabled: false}

    view = new AvailablePackageView {
      name: 'test-package'
      version: '0.1.0'
      engines:
        atom: '>99.0.0'
    }, @packageManager

    expect(view.installButton.css('display')).not.toBe('none')
    expect(view.uninstallButton.css('display')).toBe('none')
    view.installButton.click()
    expect(@packageManager.install).toHaveBeenCalled()
    expect(@packageManager.install.mostRecentCall.args[0]).toEqual({
      name: 'test-package'
      version: '0.0.1'
      engines:
        atom: '>0.50.0'
    })

  it "can't be installed if there is no version compatible with the current atom version", ->
    @packageManager.requestPackage.andCallFake (packageName, callback) ->
      pack =
        name: packageName
        releases:
          latest: '0.1.0'
        versions:
          '0.1.0':
            engines:
              atom: '>99.0.0'

      callback(null, pack)

    setPackageStatusSpies {installed: false, disabled: false}

    view = new AvailablePackageView {
      name: 'test-package'
      engines:
        atom: '>=99.0.0'
    }, @packageManager

    expect(view.installButton.css('display')).toBe('none')
    expect(view.uninstallButton.css('display')).toBe('none')
    expect(view.settingsButton.css('display')).toBe('none')
    expect(view.enablementButton.css('display')).toBe('none')
