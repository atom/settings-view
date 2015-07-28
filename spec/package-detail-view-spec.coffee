path = require 'path'

PackageDetailView = require '../lib/package-detail-view'
PackageManager = require '../lib/package-manager'

describe "PackageDetailView", ->
  packageManager = null

  beforeEach ->
    packageManager = new PackageManager

  it "Renders a package when provided in `initialize`", ->
    atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-config'))
    pack = atom.packages.getLoadedPackage('package-with-config')
    view = new PackageDetailView(pack, packageManager)

    # Perhaps there are more things to assert here.
    expect(view.title.text()).toBe('Package With Config')


  it "Does not call the atom.io api when package metadata is present"

  it "Calls the atom.io api when package metadata is missing"

  it "Shows an error page when package metadata cannot be loaded"

  it "Renders the package successfully after a call to the atom.io api"
