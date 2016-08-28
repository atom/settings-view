fs = require 'fs'
path = require 'path'

{mockedPackageManager} = require './spec-helper'

Package = require '../lib/package'
PackageDetailView = require '../lib/package-detail-view'
SnippetsProvider =
  getSnippets: -> {}

describe "PackageDetailView", ->
  [packageManager, view, pack] = []

  beforeEach ->
    atom.packages.loadPackage(path.join(__dirname, 'fixtures', 'package-with-readme'))
    packageManager = mockedPackageManager()
    pack = atom.packages.getLoadedPackage('package-with-readme')
    pack = new Package(pack, packageManager)
    view = new PackageDetailView(pack, SnippetsProvider)
    view.beforeShow()

  it "renders a package when provided in `initialize`", ->
    expect(view.title.text()).toBe('Package With Readme')

  it "shows a loading message and calls out to atom.io when package metadata is missing", ->
    expect(view.loadingMessage).not.toBe(null)
    expect(view.loadingMessage[0].classList.contains('hidden')).not.toBe(true)

  # it "shows an error when package metadata cannot be loaded via the API", ->
  #   packageManager.client = createClientSpy()
  #   packageManager.client.package.andCallFake (name, cb) ->
  #     error = new Error('API error')
  #     cb(error, null)
  #   pack = new Package({name: 'nonexistent-package'}, packageManager)
  #   view = new PackageDetailView(pack, SnippetsProvider)
  #
  #   expect(view.errorMessage[0].classList.contains('hidden')).not.toBe(true)
  #   expect(view.loadingMessage[0].classList.contains('hidden')).toBe(true)
  #   expect(view.find('.package-card').length).toBe(0)

  it "renders the README successfully after a call to the atom.io api", ->
    expect(view.packageCard).toBeDefined()
    expect(view.packageCard.packageName.text()).toBe('package-with-readme')
    expect(view.find('.package-readme').length).toBe(1)

  it "renders the README successfully with sanitized html", ->
    expect(view.find('.package-readme script').length).toBe(0)
    expect(view.find('.package-readme :checkbox[disabled]').length).toBe(2)

  it "should show 'Install' as the first breadcrumb by default", ->
    expect(view.breadcrumb.text()).toBe('Install')
