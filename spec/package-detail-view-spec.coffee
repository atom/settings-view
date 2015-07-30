path = require 'path'

PackageDetailView = require '../lib/package-detail-view'
PackageManager = require '../lib/package-manager'

fdescribe "PackageDetailView", ->
  packageManager = null

  beforeEach ->
    packageManager = new PackageManager

  it "Renders a package when provided in `initialize`", ->
    atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))
    pack = atom.packages.getLoadedPackage('package-with-config')
    view = new PackageDetailView(pack, packageManager)

    # Perhaps there are more things to assert here.
    expect(view.title.text()).toBe('Package With Config')

  it "Does not call the atom.io api for package metadata when present", ->
    packageManager.client = jasmine.createSpyObj('client', ['package', 'avatar'])
    view = new PackageDetailView({name: 'package-with-config'}, packageManager)

    # PackageCard is a subview, and it calls AtomIoClient::package once to load
    # metadata from the cache.
    expect(packageManager.client.package.callCount).toBe(1)

  it "Shows a loading message and calls out to atom.io when package metadata is missing", ->
    packageManager.client = jasmine.createSpyObj('client', ['package'])
    packageManager.client.package.andCallFake ->
      require(path.join(__dirname, 'fixtures', 'package-with-readme', 'package.json'))

    view = new PackageDetailView({name: 'package-with-readme'}, packageManager)
    expect(view.loadingMessage).not.toBe(null)
    expect(packageManager.client.package).toHaveBeenCalled()

  it "Shows an error page when package metadata cannot be loaded"

  it "Renders the package successfully after a call to the atom.io api"
