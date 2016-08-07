_ = require 'underscore-plus'
PackageManager = require '../lib/package-manager'

mockedPackageManager = (options = {}) ->
  installedPackages = options.installedPackages ? {
    dev: []
    user: []
    core: []
    git: []
  }
  deprecated = []
  featured = options.featured ? {
    themes: []
    packages: []
  }
  packageManager = new PackageManager()
  packageManager.storageKey = "settings-view-specs:package-store"
  packageManager.installedPackages = installedPackages

  for list in _.keys PackageManager.PACKAGE_LISTS
    packageManager.clearStoredList(list)

  packageManager.setDeprecated = (packageName) ->
    deprecated.push(packageName)

  packageManager.addPackage = (pack) ->
    installedPackages.user.push({name: pack.name, version: pack.version})
    installedPackages.user = _.uniq installedPackages.user

  try
    jasmine.unspy(atom.packages, 'isDeprecatedPackage')
    jasmine.unspy(atom.packages, 'loadPackage')
  catch

  spyOn(atom.packages, 'isDeprecatedPackage').andCallFake (packageName) ->
    deprecated.indexOf(packageName) > -1

  origLoad = atom.packages.loadPackage
  spyOn(atom.packages, 'loadPackage').andCallFake (name) ->
    packageManager.addPackage({name})
    origLoad.call(atom.packages, name)

  ls = (kind) ->
    result = {}

    new Promise (resolve, __) ->
      if kind is '--themes'
        _.each installedPackages, (list, listKey) ->
          result[listKey] = _.filter list, (pack) ->
            pack.theme
      else if kind is '--packages'
        _.each installedPackages, (list, listKey) ->
          result[listKey] = _.filter list, (pack) ->
            not pack.theme
      else
        result = installedPackages

      resolve(JSON.stringify result)

  featured = (kind) ->
    new Promise (resolve, reject) ->
      resolve(JSON.stringify featured[kind])

  spyOn(packageManager, 'command').andCallFake (args) ->
    switch args[0]
      when 'ls'
        ls(args[1])
      when 'featured'
        featured(args[1])
      when 'install'
        [name, version] = args[1].split('@')
        packageManager.addPackage({name, version})
        Promise.resolve(JSON.stringify {name})
      when 'uninstall'
        installedPackages.user = _.reject installedPackages.user, (pack) ->
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
