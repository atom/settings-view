module.exports =
class Package
  constructor: (pkg, @packageManager) ->
    @name = pkg.name

  # Public: Unloads the package from atom
  #
  # Returns a {Promise}
  unload: ->
    new Promise (resolve, reject) =>
      try
        atom.packages.deactivatePackage(@name) if atom.packages.isPackageActive(@name)
        atom.packages.unloadPackage(@name) if atom.packages.isPackageLoaded(@name)
        resolve()
      catch error
        reject(error)
