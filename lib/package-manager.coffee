_ = require 'underscore-plus'
{BufferedNodeProcess} = require 'atom'
{Emitter} = require 'emissary'
Q = require 'q'
semver = require 'semver'

Q.stopUnhandledRejectionTracking()

module.exports =
class PackageManager
  Emitter.includeInto(this)

  constructor: ->
    @packagePromises = []

  runCommand: (args, callback) ->
    command = atom.packages.getApmPath()
    outputLines = []
    stdout = (lines) -> outputLines.push(lines)
    errorLines = []
    stderr = (lines) -> errorLines.push(lines)
    exit = (code) ->
      callback(code, outputLines.join('\n'), errorLines.join('\n'))

    args.push('--no-color')
    new BufferedNodeProcess({command, args, stdout, stderr, exit})

  loadFeatured: (callback) ->
    args = ['featured', '--json']
    version = atom.getVersion()
    args.push('--compatible', version) if semver.valid(version)

    @runCommand args, (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch error
          callback(error)
          return

        callback(null, packages)
      else
        error = new Error('Fetching featured packages and themes failed.')
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

  loadPackage: (packageName, callback) ->
    args = ['view', packageName, '--json']

    @runCommand args, (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch error
          callback(error)
          return

        callback(null, packages)
      else
        error = new Error("Fetching package '#{packageName}' failed.")
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

  getFeatured: ->
    @featuredPromise ?= Q.nbind(@loadFeatured, this)()

  getPackage: (packageName) ->
    @packagePromises[packageName] ?= Q.nbind(@loadPackage, this, packageName)()

  search: (query) ->
    deferred = Q.defer()

    args = ['search', query, '--json']
    @runCommand args, (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
          deferred.resolve(packages)
        catch error
          deferred.reject(error)
      else
        error = new Error("Searching for \u201C#{query}\u201D failed.")
        error.stdout = stdout
        error.stderr = stderr
        deferred.reject(error)

    deferred.promise

  update: (pack, newVersion, callback) ->
    {name, theme} = pack

    activateOnSuccess = not theme and not atom.packages.isPackageDisabled(name)
    activateOnFailure = atom.packages.isPackageActive(name)
    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)
    atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)

    args = ['install', "#{name}@#{newVersion}"]
    exit = (code, stdout, stderr) =>
      if code is 0
        if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        callback?()
        if theme
          @emit 'theme-updated', pack
        else
          @emit 'package-updated', pack
      else
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error("Updating to \u201C#{name}@#{newVersion}\u201D failed.")
        error.stdout = stdout
        error.stderr = stderr
        if theme
          @emit 'theme-update-failed', pack, error
        else
          @emit 'package-update-failed', pack, error
        callback(error)

    @runCommand(args, exit)

  install: (pack, callback) ->
    {name, version, theme} = pack
    activateOnSuccess = not theme and not atom.packages.isPackageDisabled(name)
    activateOnFailure = atom.packages.isPackageActive(name)
    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)
    atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)

    args = ['install', "#{name}@#{version}"]
    exit = (code, stdout, stderr) =>
      if code is 0
        if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        callback?()
        if theme
          @emit 'theme-installed', pack
        else
          @emit 'package-installed', pack
      else
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error("Installing \u201C#{name}@#{version}\u201D failed.")
        error.stdout = stdout
        error.stderr = stderr
        if theme
          @emit 'theme-install-failed', pack, error
        else
          @emit 'package-install-failed', pack, error
        callback(error)

    @runCommand(args, exit)

  uninstall: (pack, callback) ->
    {name, theme} = pack
    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)

    @runCommand ['uninstall', '--hard', name], (code, stdout, stderr) =>
      if code is 0
        atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)
        callback?()
        if theme
          @emit 'theme-uninstalled', pack
        else
          @emit 'package-uninstalled', pack
      else
        error = new Error("Uninstalling \u201C#{name}\u201D failed.")
        error.stdout = stdout
        error.stderr = stderr
        if theme
          @emit 'theme-uninstall-failed', pack, error
        else
          @emit 'package-uninstall-failed', pack, error
        callback(error)

  canUpgrade: (installedPackage, availablePackage) ->
    return false unless installedPackage? and availablePackage?

    installedVersion = installedPackage.metadata.version
    return false unless semver.valid(installedVersion)

    availableVersion = availablePackage.version
    return false unless semver.valid(availableVersion)

    semver.gt(availableVersion, installedVersion)

  getPackageTitle: ({name}) ->
    _.undasherize(_.uncamelcase(name))
