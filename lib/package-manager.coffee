_ = require 'underscore-plus'
{BufferedProcess, CompositeDisposable, Emitter} = require 'atom'
Q = require 'q'
semver = require 'semver'

Client = require './atom-io-client'

Q.stopUnhandledRejectionTracking()

module.exports =
class PackageManager
  constructor: ->
    @packagePromises = []
    @availablePackageCache = null
    @emitter = new Emitter

  getClient: ->
    @client ?= new Client(this)

  isPackageInstalled: (packageName) ->
    if atom.packages.isPackageLoaded(packageName)
      true
    else if packageNames = @getAvailablePackageNames()
      packageNames.indexOf(packageName) > -1
    else
      false

  packageHasSettings: (packageName) ->
    pack = atom.packages.getLoadedPackage(packageName)
    pack.activateConfig() if pack? and not atom.packages.isPackageActive(packageName)
    schema = atom.config.getSchema(packageName)
    schema? and (schema.type isnt 'any')

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
    errorMessage = 'Fetching local packages failed.'
    apmProcess = @runCommand args, (code, stdout, stderr) =>
      if code is 0
        try
          packages = JSON.parse(stdout)
        catch parseError
          error = createJsonParseError(errorMessage, parseError, stdout)
          return callback(error)
        @cacheAvailablePackageNames(packages)
        callback(null, packages)
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    handleProcessErrors(apmProcess, errorMessage, callback)

  loadFeatured: (loadThemes, callback) ->
    unless callback
      callback = loadThemes
      loadThemes = false

    args = ['featured', '--json']
    version = atom.getVersion()
    args.push('--themes') if loadThemes
    args.push('--compatible', version) if semver.valid(version)
    errorMessage = 'Fetching featured packages failed.'

    apmProcess = @runCommand args, (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch parseError
          error = createJsonParseError(errorMessage, parseError, stdout)
          return callback(error)

        callback(null, packages)
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    handleProcessErrors(apmProcess, errorMessage, callback)

  loadOutdated: (callback) ->
    args = ['outdated', '--json']
    version = atom.getVersion()
    args.push('--compatible', version) if semver.valid(version)
    errorMessage = 'Fetching outdated packages and themes failed.'

    apmProcess = @runCommand args, (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch parseError
          error = createJsonParseError(errorMessage, parseError, stdout)
          return callback(error)

        callback(null, packages)
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    handleProcessErrors(apmProcess, errorMessage, callback)

  loadPackage: (packageName, callback) ->
    args = ['view', packageName, '--json']
    errorMessage = "Fetching package '#{packageName}' failed."

    apmProcess = @runCommand args, (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch parseError
          error = createJsonParseError(errorMessage, parseError, stdout)
          return callback(error)

        callback(null, packages)
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    handleProcessErrors(apmProcess, errorMessage, callback)

  loadCompatiblePackageVersion: (packageName, callback) ->
    args = ['view', packageName, '--json', '--compatible', @normalizeVersion(atom.getVersion())]
    errorMessage = "Fetching package '#{packageName}' failed."

    apmProcess = @runCommand args, (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch parseError
          error = createJsonParseError(errorMessage, parseError, stdout)
          return callback(error)

        callback(null, packages)
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    handleProcessErrors(apmProcess, errorMessage, callback)

  getInstalled: ->
    Q.nbind(@loadInstalled, this)()

  getFeatured: (loadThemes) ->
    Q.nbind(@loadFeatured, this, !!loadThemes)()

  getOutdated: ->
    Q.nbind(@loadOutdated, this)()

  getPackage: (packageName) ->
    @packagePromises[packageName] ?= Q.nbind(@loadPackage, this, packageName)()

  satisfiesVersion: (version, metadata) ->
    engine = metadata.engines?.atom ? '*'
    return false unless semver.validRange(engine)
    return semver.satisfies(version, engine)

  normalizeVersion: (version) ->
    [version] = version.split('-') if typeof version is 'string'
    version

  search: (query, options = {}) ->
    deferred = Q.defer()

    args = ['search', query, '--json']
    if options.themes
      args.push '--themes'
    else if options.packages
      args.push '--packages'
    errorMessage = "Searching for \u201C#{query}\u201D failed."

    apmProcess = @runCommand args, (code, stdout, stderr) ->
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
          deferred.resolve(packages)
        catch parseError
          error = createJsonParseError(errorMessage, parseError, stdout)
          deferred.reject(error)
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        deferred.reject(error)

    handleProcessErrors apmProcess, errorMessage, (error) ->
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
    atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)

    errorMessage = "Updating to \u201C#{name}@#{newVersion}\u201D failed."
    onError = (error) =>
      error.packageInstallError = not theme
      @emitPackageEvent 'update-failed', pack, error
      callback(error)

    args = ['install', "#{name}@#{newVersion}"]
    exit = (code, stdout, stderr) =>
      if code is 0
        activation = if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        Promise.resolve(activation).then =>
          callback?()
          @emitPackageEvent 'updated', pack
      else
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        onError(error)

    @emitter.emit('package-updating', {pack})
    apmProcess = @runCommand(args, exit)
    handleProcessErrors(apmProcess, errorMessage, onError)

  unload: (name) ->
    if atom.packages.isPackageLoaded(name)
      atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)
      atom.packages.unloadPackage(name)

  install: (pack, callback) ->
    {name, version, theme} = pack
    activateOnSuccess = not theme and not atom.packages.isPackageDisabled(name)
    activateOnFailure = atom.packages.isPackageActive(name)

    @unload(name)
    if version?
      args = ['install', "#{name}@#{version}"]
    else
      args = ['install', "#{name}"]

    errorMessage = "Installing \u201C#{name}@#{version}\u201D failed."
    onError = (error) =>
      error.packageInstallError = not theme
      @emitPackageEvent 'install-failed', pack, error
      callback(error)

    exit = (code, stdout, stderr) =>
      if code is 0
        if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        @addPackageToAvailablePackageNames(name)
        callback?()
        @emitPackageEvent 'installed', pack
      else
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        onError(error)

    @emitPackageEvent('installing', pack)
    apmProcess = @runCommand(args, exit)
    handleProcessErrors(apmProcess, errorMessage, onError)

  uninstall: (pack, callback) ->
    {name} = pack

    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)

    errorMessage = "Uninstalling \u201C#{name}\u201D failed."
    onError = (error) =>
      @emitPackageEvent 'uninstall-failed', pack, error
      callback(error)

    @emitPackageEvent('uninstalling', pack)
    apmProcess = @runCommand ['uninstall', '--hard', name], (code, stdout, stderr) =>
      if code is 0
        @unload(name)
        @removePackageFromAvailablePackageNames(name)
        @removePackageNameFromDisabledPackages(name)
        callback?()
        @emitPackageEvent 'uninstalled', pack
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        onError(error)

    handleProcessErrors(apmProcess, errorMessage, onError)

  installAlternative: (pack, alternativePackageName, callback) ->
    eventArg = {pack, alternative: alternativePackageName}
    @emitter.emit('package-installing-alternative', eventArg)

    uninstallPromise = new Promise (resolve, reject) =>
      @uninstall pack, (error) ->
        if error then reject(error) else resolve()

    installPromise = new Promise (resolve, reject) =>
      @install {name: alternativePackageName}, (error) ->
        if error then reject(error) else resolve()

    Promise.all([uninstallPromise, installPromise]).then =>
      callback(null, eventArg)
      @emitter.emit('package-installed-alternative', eventArg)
    .catch (error) =>
      console.error error.message, error.stack
      callback(error, eventArg)
      eventArg.error = error
      @emitter.emit('package-install-alternative-failed', eventArg)

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
    if repoUrl.match 'git@github'
      repoName = repoUrl.split(':')[1]
      repoUrl = "https://github.com/#{repoName}"
    repoUrl.replace(/\.git$/, '').replace(/\/+$/, '').replace(/^git\+/, '')

  checkNativeBuildTools: ->
    deferred = Q.defer()

    apmProcess = @runCommand ['install', '--check'], (code, stdout, stderr) ->
      if code is 0
        deferred.resolve()
      else
        deferred.reject(new Error())

    apmProcess.onWillThrowError ({error, handle}) ->
      handle()
      deferred.reject(error)

    deferred.promise

  removePackageNameFromDisabledPackages: (packageName) ->
    atom.config.removeAtKeyPath('core.disabledPackages', packageName)

  cacheAvailablePackageNames: (packages) ->
    @availablePackageCache = []
    for packageType in ['core', 'user', 'dev']
      continue unless packages[packageType]?
      packageNames = (pack.name for pack in packages[packageType])
      @availablePackageCache.push(packageNames...)
    @availablePackageCache

  addPackageToAvailablePackageNames: (packageName) ->
    @availablePackageCache ?= []
    @availablePackageCache.push(packageName) if @availablePackageCache.indexOf(packageName) < 0
    @availablePackageCache

  removePackageFromAvailablePackageNames: (packageName) ->
    @availablePackageCache ?= []
    index = @availablePackageCache.indexOf(packageName)
    @availablePackageCache.splice(index, 1) if index > -1
    @availablePackageCache

  getAvailablePackageNames: ->
    @availablePackageCache

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
    @emitter.emit(eventName, {pack, error})

  on: (selectors, callback) ->
    subscriptions = new CompositeDisposable
    for selector in selectors.split(" ")
      subscriptions.add @emitter.on(selector, callback)
    subscriptions

createJsonParseError = (message, parseError, stdout) ->
  error = new Error(message)
  error.stdout = ''
  error.stderr = "#{parseError.message}: #{stdout}"
  error

createProcessError = (message, processError) ->
  error = new Error(message)
  error.stdout = ''
  error.stderr = processError.message
  error

handleProcessErrors = (apmProcess, message, callback) ->
  apmProcess.onWillThrowError ({error, handle}) ->
    handle()
    callback(createProcessError(message, error))
