_ = require 'underscore-plus'
path = require 'path'
PackageManager = require '../lib/package-manager'

mockedPackageManager = (options = {}) ->
  packageManager = new PackageManager()

  packageManager.installedPackages = options.installedPackages ? {
    dev: []
    user: []
    core: []
    git: []
  }


  packageManager.storageKey = "settings-view-specs:package-store"
  packageManager.outdated = []
  packageManager.deprecated = []
  packageManager.featured = options.featured ? []

  atom.packages.packageDirPaths.push(path.join(__dirname, 'fixtures'))

  for list in _.keys PackageManager.PACKAGE_LISTS
    packageManager.clearStoredList(list)

  packageManager.setDeprecated = (packageName) ->
    packageManager.deprecated.push(packageName)

  packageManager.addPackage = (pack) ->
    installedPack = _.filter(packageManager.installedPackages.user, (pkg) ->
      pkg.name is pack.name)[0]

    unless installedPack
      packageManager.installedPackages.user.push({name: pack.name, version: pack.version, theme: pack.theme})

  try
    jasmine.unspy(atom.packages, 'isDeprecatedPackage')
    jasmine.unspy(atom.packages, 'loadPackage')
    jasmine.unspy(atom.packages, 'getAvailablePackageNames')
  catch

  spyOn(atom.packages, 'isDeprecatedPackage').andCallFake (packageName) ->
    packageManager.deprecated.indexOf(packageName) >= 0

  spyOn(atom.packages, 'getAvailablePackageNames').andReturn(packageManager.installedPackages.user)

  origLoad = atom.packages.loadPackage
  spyOn(atom.packages, 'loadPackage').andCallFake (name) ->
    packageManager.addPackage({name})
    try
      origLoad.call(atom.packages, name)
    catch

  ls = (kind) ->
    result = {}

    new Promise (resolve, __) ->
      if kind is '--themes'
        _.each packageManager.installedPackages, (list, listKey) ->
          result[listKey] = _.filter list, (pack) ->
            pack.theme
      else if kind is '--packages'
        _.each packageManager.installedPackages, (list, listKey) ->
          result[listKey] = _.filter list, (pack) ->
            not pack.theme
      else
        result = packageManager.installedPackages

      resolve(JSON.stringify result)


  spyOn(packageManager, 'command').andCallFake (args) ->
    switch args[0]
      when 'ls'
        ls(args[1])
      when 'featured'
        Promise.resolve(JSON.stringify packageManager.featured)
      when 'outdated'
        Promise.resolve(JSON.stringify packageManager.outdated)
      when 'install'
        [name, version] = args[1].split('@')
        theme = name.endsWith('-theme')
        packageManager.addPackage({name, version, theme})
        Promise.resolve(JSON.stringify {name})
      when 'uninstall'
        packageManager.installedPackages.user = _.reject packageManager.installedPackages.user, (pack) ->
          pack.name is args[2]
      when 'view'
        [name, version] = args[1].split('@')
        Promise.resolve([{name}])
      else
        Promise.resolve()

  spyOn(packageManager, 'update').andCallThrough()
  spyOn(packageManager, 'install').andCallThrough()
  spyOn(packageManager, 'installAlternative').andCallThrough()
  spyOn(packageManager, 'uninstall').andCallThrough()
  spyOn(packageManager, 'asset').andCallThrough()

  packageManager

module.exports = {
  mockedPackageManager
}
