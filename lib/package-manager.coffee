_ = require 'underscore-plus'
{BufferedProcess, CompositeDisposable, Emitter} = require 'atom'
semver = require 'semver'

Client = require './atom-io-client'

module.exports =
class PackageManager
  # Millisecond expiry for cached loadOutdated, etc. values
  CACHE_EXPIRY: 1000*60*10

  constructor: ->
    @packagePromises = []
    @apmCache =
      loadOutdated:
        value: null
        expiry: 0

    @emitter = new Emitter

  getClient: ->
    @client ?= new Client(this)

  isPackageInstalled: (packageName) ->
    if atom.packages.isPackageLoaded(packageName)
      true
    else
      atom.packages.getAvailablePackageNames().indexOf(packageName) > -1

  packageHasSettings: (packageName) ->
    grammars = atom.grammars.getGrammars() ? []
    for grammar in grammars when grammar.path
      return true if grammar.packageName is packageName

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

  loadOutdated: (clearCache, callback) ->
    if clearCache
      @clearOutdatedCache()
    # Short circuit if we have cached data.
    else if @apmCache.loadOutdated.value and @apmCache.loadOutdated.expiry > Date.now()
      return callback(null, @apmCache.loadOutdated.value)

    args = ['outdated', '--json']
    version = atom.getVersion()
    args.push('--compatible', version) if semver.valid(version)
    errorMessage = 'Fetching outdated packages and themes failed.'

    apmProcess = @runCommand args, (code, stdout, stderr) =>
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch parseError
          error = createJsonParseError(errorMessage, parseError, stdout)
          return callback(error)

        @apmCache.loadOutdated =
          value: packages
          expiry: Date.now() + @CACHE_EXPIRY

        for pack in packages
          @emitPackageEvent 'update-available', pack

        callback(null, packages)
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    handleProcessErrors(apmProcess, errorMessage, callback)

  clearOutdatedCache: ->
    @apmCache.loadOutdated =
      value: null
      expiry: 0

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
    new Promise (resolve, reject) =>
      @loadInstalled (error, result) ->
        if error
          reject(error)
        else
          resolve(result)

  getFeatured: (loadThemes) ->
    new Promise (resolve, reject) =>
      @loadFeatured !!loadThemes, (error, result) ->
        if error
          reject(error)
        else
          resolve(result)

  getOutdated: (clearCache = false) ->
    new Promise (resolve, reject) =>
      @loadOutdated clearCache, (error, result) ->
        if error
          reject(error)
        else
          resolve(result)

  getPackage: (packageName) ->
    @packagePromises[packageName] ?= new Promise (resolve, reject) =>
      @loadPackage packageName, (error, result) ->
        if error
          reject(error)
        else
          resolve(result)

  satisfiesVersion: (version, metadata) ->
    engine = metadata.engines?.atom ? '*'
    return false unless semver.validRange(engine)
    return semver.satisfies(version, engine)

  normalizeVersion: (version) ->
    [version] = version.split('-') if typeof version is 'string'
    version

  search: (query, options = {}) ->
    new Promise (resolve, reject) =>
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
            if options.sortBy
              packages = _.sortBy packages, (pkg) ->
                return pkg[options.sortBy]*-1

            resolve(packages)
          catch parseError
            error = createJsonParseError(errorMessage, parseError, stdout)
            reject(error)
        else
          error = new Error(errorMessage)
          error.stdout = stdout
          error.stderr = stderr
          reject(error)

      handleProcessErrors apmProcess, errorMessage, (error) ->
        reject(error)

  update: (pack, newVersion, callback) ->
    {name, theme, apmInstallSource} = pack

    errorMessage = if newVersion
      "Updating to \u201C#{name}@#{newVersion}\u201D failed."
    else
      "Updating to latest sha failed."
    onError = (error) =>
      error.packageInstallError = not theme
      @emitPackageEvent 'update-failed', pack, error
      callback?(error)

    if apmInstallSource?.type is 'git'
      args = ['install', apmInstallSource.source]
    else
      args = ['install', "#{name}@#{newVersion}"]

    exit = (code, stdout, stderr) =>
      if code is 0
        @clearOutdatedCache()
        callback?()
        @emitPackageEvent 'updated', pack
      else
        error = new Error(errorMessage)
        error.stdout = stdout
        error.stderr = stderr
        onError(error)

    @emitPackageEvent 'updating', pack
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
    nameWithVersion = if version? then "#{name}@#{version}" else name

    @unload(name)
    args = ['install', nameWithVersion, '--json']

    errorMessage = "Installing \u201C#{nameWithVersion}\u201D failed."
    onError = (error) =>
      error.packageInstallError = not theme
      @emitPackageEvent 'install-failed', pack, error
      callback?(error)

    exit = (code, stdout, stderr) =>
      if code is 0
        # get real package name from package.json
        try
          packageInfo = JSON.parse(stdout)[0]
          pack = _.extend({}, pack, packageInfo.metadata)
          name = pack.name
        catch err
          # using old apm without --json support
        @clearOutdatedCache()
        if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

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
      callback?(error)

    @emitPackageEvent('uninstalling', pack)
    apmProcess = @runCommand ['uninstall', '--hard', name], (code, stdout, stderr) =>
      if code is 0
        @clearOutdatedCache()
        @unload(name)
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
    new Promise (resolve, reject) =>
      apmProcess = @runCommand ['install', '--check'], (code, stdout, stderr) ->
        if code is 0
          resolve()
        else
          reject(new Error())

      apmProcess.onWillThrowError ({error, handle}) ->
        handle()
        reject(error)

  removePackageNameFromDisabledPackages: (packageName) ->
    atom.config.removeAtKeyPath('core.disabledPackages', packageName)

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
