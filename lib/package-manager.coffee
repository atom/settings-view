_ = require 'underscore-plus'
{BufferedNodeProcess} = require 'atom'
{Emitter} = require 'emissary'
Q = require 'q'
semver = require 'semver'

Q.stopUnhandledRejectionTracking()

module.exports =
class PackageManager
  Emitter.includeInto(this)

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

  loadAvailable: (callback) ->
    @runCommand ['available', '--json'], (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch error
          callback(error)
          return

        callback(null, packages)
      else
        error = new Error('Fetching available packages and themes failed.')
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

  getAvailable: ->
    @availablePromise ?= Q.nbind(@loadAvailable, this)()

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
        error = new Error("Updating to '#{name}@#{newVersion}' failed.")
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
        error = new Error("Installing '#{name}@#{version}' failed.")
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

    @runCommand ['uninstall', name], (code, stdout, stderr) =>
      if code is 0
        atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)
        callback?()
        if theme
          @emit 'theme-uninstalled', pack
        else
          @emit 'package-uninstalled', pack
      else
        error = new Error("Uninstalling '#{name}' failed.")
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
