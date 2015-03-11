_ = require 'underscore-plus'
{BufferedProcess} = require 'atom'
{Emitter} = require 'emissary'
Q = require 'q'
semver = require 'semver'
url = require 'url'

Client = require './atom-io-client'

Q.stopUnhandledRejectionTracking()

module.exports =
class PackageManager
  Emitter.includeInto(this)

  constructor: ->
    @packagePromises = []

  getClient: ->
    @client ?= new Client(this)

  runCommand: (args, callback) ->
    command = atom.packages.getApmPath()
    outputLines = []
    stdout = (lines) -> outputLines.push(lines)
    errorLines = []
    stderr = (lines) -> errorLines.push(lines)
    exit = (code) ->
      callback(code, outputLines.join('\n'), errorLines.join('\n'))

    args.push('--no-color')
    new BufferedProcess({command, args, stdout, stderr, exit})

  loadInstalled: (callback) ->
    args = ['ls', '--json']
    @runCommand args, (code, stdout, stderr) ->
      if code is 0
        packages = JSON.parse(stdout)
        callback(null, packages)
      else
        error = new Error('Fetching local packages failed.')
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

  loadFeatured: (loadThemes, callback) ->
    unless callback
      callback = loadThemes
      loadThemes = false

    args = ['featured', '--json']
    version = atom.getVersion()
    args.push('--themes') if loadThemes
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
        error = new Error('Fetching featured packages failed.')
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

  loadOutdated: (callback) ->
    args = ['outdated', '--json']
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
        error = new Error('Fetching outdated packages and themes failed.')
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

  getInstalled: ->
    Q.nbind(@loadInstalled, this)()

  getFeatured: (loadThemes) ->
    Q.nbind(@loadFeatured, this, !!loadThemes)()

  getOutdated: ->
    Q.nbind(@loadOutdated, this)()

  getPackage: (packageName) ->
    @packagePromises[packageName] ?= Q.nbind(@loadPackage, this, packageName)()

  search: (query, options = {}) ->
    deferred = Q.defer()

    args = ['search', query, '--json']
    if options.themes
      args.push '--themes'
    else if options.packages
      args.push '--packages'

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

    if theme
      activateOnSuccess = atom.packages.isPackageActive(name)
    else
      activateOnSuccess = not atom.packages.isPackageDisabled(name)
    activateOnFailure = atom.packages.isPackageActive(name)
    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)
    if atom.packages.isPackageLoaded(name)
      # remove old version from node.js module cache
      delete require.cache[atom.packages.getLoadedPackage(name).getMainModulePath()]
      atom.packages.unloadPackage(name)

    args = ['install', "#{name}@#{newVersion}"]
    exit = (code, stdout, stderr) =>
      if code is 0
        if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        callback?()
        @emitPackageEvent 'updated', pack
      else
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error("Updating to \u201C#{name}@#{newVersion}\u201D failed.")
        error.stdout = stdout
        error.stderr = stderr
        error.packageInstallError = not theme
        @emitPackageEvent 'update-failed', pack, error
        callback(error)

    @emit('package-updating', pack)
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
        @emitPackageEvent 'installed', pack
      else
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error("Installing \u201C#{name}@#{version}\u201D failed.")
        error.stdout = stdout
        error.stderr = stderr
        error.packageInstallError = not theme
        @emitPackageEvent 'install-failed', pack, error
        callback(error)

    @runCommand(args, exit)

  uninstall: (pack, callback) ->
    {name} = pack

    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)

    @runCommand ['uninstall', '--hard', name], (code, stdout, stderr) =>
      if code is 0
        atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)
        callback?()
        @emitPackageEvent 'uninstalled', pack
      else
        error = new Error("Uninstalling \u201C#{name}\u201D failed.")
        error.stdout = stdout
        error.stderr = stderr
        @emitPackageEvent 'uninstall-failed', pack, error
        callback(error)

  canUpgrade: (installedPackage, availableVersion) ->
    return false unless installedPackage?

    installedVersion = installedPackage.metadata.version
    return false unless semver.valid(installedVersion)
    return false unless semver.valid(availableVersion)

    semver.gt(availableVersion, installedVersion)

  getPackageTitle: ({name}) ->
    _.undasherize(_.uncamelcase(name))

  getRepositoryUrl: ({metadata}) ->
    {repository} = metadata
    repoUrl = repository?.url ? repository ? ''
    repoUrl.replace(/\.git$/, '').replace(/\/+$/, '')

  checkNativeBuildTools: ->
    deferred = Q.defer()

    @runCommand ['install', '--check'], (code, stdout, stderr) =>
      if code is 0
        deferred.resolve()
      else
        deferred.reject(new Error())

    deferred.promise

  # Emits the appropriate event for the given package.
  #
  # All events are either of the form `theme-foo` or `package-foo` depending on
  # whether the event is for a theme or a normal package. This method standardizes
  # the logic to determine if a package is a theme or not and formats the event
  # name appropriately.
  #
  # eventName - The event name suffix {String} of the event to emit.
  # pack - The package for which the event is being emitted.
  # error - Any error information to be included in the case of an error.
  emitPackageEvent: (eventName, pack, error) ->
    theme = pack.theme ? pack.metadata?.theme
    eventName = if theme then "theme-#{eventName}" else "package-#{eventName}"
    @emit eventName, pack, error
