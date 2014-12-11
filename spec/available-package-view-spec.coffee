AvailablePackageView = require '../lib/available-package-view'

describe "AvailablePackageView", ->
  it "doesn't show the disable control for a theme", ->
    packageManager = jasmine.createSpyObj('packageManager', ['on'])
    spyOn(AvailablePackageView.prototype, 'isInstalled').andReturn(true)
    spyOn(AvailablePackageView.prototype, 'isDisabled').andReturn(false)

    view = new AvailablePackageView {theme: 'syntax', name: 'test-theme'}, packageManager
    expect(view.enablementButton.css('display')).toBe('none')
