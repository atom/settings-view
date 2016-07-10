module.exports =
class Package
  constructor: (pkg, @packageManager) ->
    @name = pkg.name
    @theme = pkg.theme
    @version = pkg.version

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

  # Public: Installs the package for atom and enables it if it was disabled before
  #
  # Returns a {Promise}
  install: ->
    @unload()
      .then =>
        @packageManager.install(this)
      .then =>
        @enable() if @isDisabled()

  # Public: Updates the package for atom
  #
  # * `newVersion` {String} version to be updated to
  #
  # Returns a {Promise}
  update: (newVersion) ->
    @unload()
      .then =>
        @packageManager.update(this, newVersion)

  enable: ->
    atom.packages.enablePackage(@pack.name)

  isDisabled: ->
    atom.packages.isPackageDisabled(@name)
