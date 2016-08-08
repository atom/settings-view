_ = require 'underscore-plus'
{BufferedProcess, CompositeDisposable, Emitter} = require 'atom'
semver = require 'semver'

Client = require './atom-io-client'
CachedAssets = require './cached-assets'

module.exports =
class PackageManager
  constructor: ->
    @availablePackageCache = null
    @emitter = new Emitter
    @storageKey = "settings-view:package-store"
    @assetCache ?= new CachedAssets()


  # Public: Gets an asset from the @assetCache
  #
  # * `url` {String} to be requested from the asset-cache
  #
  # Returns a {Promise} resolving with the assetPath
  asset: (url) ->
    @assetCache.asset(url)

  # Returns a key for a list for storing in localStorage
  #
  # * `listName` {String} in the format of `LIST[:SUB-LIST]`
  #
  storeKeyForList: (listName) ->
    "#{@storageKey}:list:#{listName}"

  # Returns a key for a package for storing in localStorage
  #
  # * `packageName` {String}
  #
  storeKeyForPackage: (packageName) ->
    "#{@storageKey}:package:#{packageName}"

  # Public: Takes a {Package} object, grabs additional data and saves it to localStorage
  #
  # * `pack` {Package} object
  #
  # Returns an {Object}
  storePackage: (pack) ->
    properties = [
      'name', 'version', 'latestVersion', 'description', 'readme',
      'downloads', 'stargazers_count', 'repository',
      'metadata', 'path', 'apmInstallSource', 'gitUrlInfo',
      'activateTime', 'loadTime', 'bundledPackage', 'compatible'
    ]

    if storedPackage = @storedPackage(pack.name)
      pack = _.extend pack, _.pick(storedPackage, properties)

    pack = _.pick pack, properties

    if loadedPackage = atom.packages.getLoadedPackage(pack.name)
      pack = _.extend pack, _.pick(loadedPackage, properties)

    localStorage.setItem("#{@storageKey}:package:#{pack.name}", JSON.stringify(pack))
    @storedPackage(pack.name)

  # Public: Retrives a Package from localStorage
  #
  # * `packName` {String}
  #
  # Returns an {Object}
  storedPackage: (packName) ->
    stored = localStorage.getItem("#{@storageKey}:package:#{packName}")
    JSON.parse(stored) if stored

  # Public: Runs `apm` with the provided arguments and an optional errorMessage
  #
  # * `args` {Array} to be used to execute `apm`
  # * `errorMessage` (optional) {String}
  #
  # Returns a {Promise} resolving with the command output
  command: (args, errorMessage = "Running apm failed") ->
    command = atom.packages.getApmPath()
    outputLines = []
    errorLines = []

    args.push('--no-color')

    new Promise (resolve, reject) ->
      stdout = (lines) -> outputLines.push(lines)
      stderr = (lines) -> errorLines.push(lines)
      exit = (code) ->
        if code is 0
          resolve(outputLines.join('\n'))
        else
          error = new Error(errorMessage)
          error.stdout = stdout
          error.stderr = stderr
          reject(error)

      apmProcess = new BufferedProcess({command, args, stdout, stderr, exit})
      apmProcess.onWillThrowError ({processError, handle}) ->
        handle()
        error = new Error(processError.message)
        error.stdout = ''
        error.stderr = stderr
        reject(error)

  # Public: Runs `::command` with `--json` as additional argument
  #
  # * `args` {Array} to be used to execute `apm`
  # * `errorMessage` (optional) {String}
  #
  # Returns a {Promise} resolving with parsed JSON
  jsonCommand: (args, errorMessage = "Running apm with --json failed") ->
    args.push('--json')

    @command(args, errorMessage)
      .then (result) =>
        @parseJSON(result, errorMessage)

  parseJSON: (jsonString, errorMessage = "Parsing JSON failed") ->
    new Promise (resolve, reject) ->
      try
        parsedJson = JSON.parse(jsonString) ? []
        resolve(parsedJson)
      catch parseError
        error = new Error(errorMessage)
        error.stdout = ''
        error.stderr = "#{parseError.message}: #{jsonString}"
        reject(error)

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
    grammars = atom.grammars.getGrammars() ? []
    for grammar in grammars when grammar.path
      return true if grammar.packageName is packageName

    pack = atom.packages.getLoadedPackage(packageName)
    pack.activateConfig() if pack? and not atom.packages.isPackageActive(packageName)
    schema = atom.config.getSchema(packageName)
    schema? and (schema.type isnt 'any')

  loadCompatiblePackageVersion: (packageName) ->
    args = ['view', packageName, '--compatible', @normalizeVersion(atom.getVersion())]
    errorMessage = "Fetching package '#{packageName}' failed."

    @jsonCommand(args, errorMessage)

  getInstalled: ->
    args = ['ls', '--json']
    errorMessage = 'Fetching local packages failed.'

    @jsonCommand(args, errorMessage)

  getFeatured: (loadThemes) ->
    args = ['featured', '--json']
    version = atom.getVersion()
    args.push('--themes') if loadThemes
    args.push('--compatible', version) if semver.valid(version)
    errorMessage = 'Fetching featured packages failed.'

    @jsonCommand(args, errorMessage)

  getOutdated: ->
    args = ['outdated', '--json']
    version = atom.getVersion()
    args.push('--compatible', version) if semver.valid(version)
    errorMessage = 'Fetching outdated packages and themes failed.'

    @jsonCommand(args, errorMessage)

  getPackage: (packageName) ->
    args = ['view', packageName, '--json']
    errorMessage = "Fetching package '#{packageName}' failed."

    @jsonCommand(args, errorMessage)

  satisfiesVersion: (version, metadata) ->
    engine = metadata.engines?.atom ? '*'
    return false unless semver.validRange(engine)
    return semver.satisfies(version, engine)

  normalizeVersion: (version) ->
    [version] = version.split('-') if typeof version is 'string'
    version

  search: (query, options = {}) ->
    args = ['search', query]
    if options.themes
      args.push '--themes'
    else if options.packages
      args.push '--packages'
    errorMessage = "Searching for \u201C#{query}\u201D failed."

    @jsonCommand(args, errorMessage)
      .then (packages) ->
        if options.sortBy
          _.sortBy packages, (pkg) ->
            pkg[options.sortBy] * -1

  update: (pack, newVersion) ->
    {name, theme, apmInstallSource} = pack

    if theme
      activateOnSuccess = atom.packages.isPackageActive(name)
    else
      activateOnSuccess = not atom.packages.isPackageDisabled(name)
    activateOnFailure = atom.packages.isPackageActive(name)

    errorMessage = if newVersion
      "Updating to \u201C#{name}@#{newVersion}\u201D failed."
    else
      "Updating to latest sha failed."

    if apmInstallSource?.type is 'git'
      args = ['install', apmInstallSource.source]
    else
      args = ['install', "#{name}@#{newVersion}"]

    @unload(name)
      .then =>
        @emitPackageEvent('updating', {pack})
        @command(args, errorMessage)
      .then =>
        activation = if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        Promise.resolve(activation).then =>
          @emitPackageEvent 'updated', pack
      .catch (error) =>
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error(errorMessage)
        error.packageInstallError = not theme
        @emitPackageEvent 'update-failed', pack, error

  unload: (name) ->
    new Promise (resolve, reject) ->
      try
        atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)
        atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)
        resolve()
      catch error
        reject(error)

  install: (pack) ->
    {name, version, theme} = pack
    activateOnSuccess = not theme and not atom.packages.isPackageDisabled(name)
    activateOnFailure = atom.packages.isPackageActive(name)
    nameWithVersion = if version? then "#{name}@#{version}" else name
    args = ['install', nameWithVersion, '--json']
    errorMessage = "Installing \u201C#{nameWithVersion}\u201D failed."

    @unload(name)
      .then =>
        @emitPackageEvent 'installing', pack
        @command(args, errorMessage)
      .then (json) =>
        # get real package name from package.json
        try
          packageInfo = JSON.parse(json)
          pack = _.extend({}, pack, packageInfo.metadata)
          name = pack.name
        catch err
          # using old apm without --json support

        if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        @addPackageToAvailablePackageNames(name)
        @emitPackageEvent 'installed', pack

        pack
      .catch (error) =>
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error(errorMessage)
        error.packageInstallError = not theme
        @emitPackageEvent 'install-failed', pack, error

  uninstall: (pack) ->
    {name} = pack
    args = ['uninstall', '--hard', name]
    errorMessage = "Uninstalling \u201C#{name}\u201D failed."

    @unload(name)
      .then =>
        @emitPackageEvent 'uninstalling', pack
        @command(args, errorMessage)
      .then =>
        @removePackageFromAvailablePackageNames(name)
        @removePackageNameFromDisabledPackages(name)
        @emitPackageEvent 'uninstalled', pack
      .catch (error) =>
        @emitPackageEvent 'uninstall-failed', pack, error

  installAlternative: (pack, alternativePackageName) ->
    eventArg = {pack, alternative: alternativePackageName}
    @emitPackageEvent('package-installing-alternative', eventArg)

    uninstallPromise = @uninstall pack
    installPromise = @install {name: alternativePackageName}

    Promise.all([uninstallPromise, installPromise])
      .then =>
        @emitPackageEvent('installed-alternative', eventArg)
      .catch (error) =>
        eventArg.error = error
        @emitPackageEvent('install-alternative-failed', eventArg)

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
    @command(['install', '--check'])

  removePackageNameFromDisabledPackages: (packageName) ->
    atom.config.removeAtKeyPath('core.disabledPackages', packageName)

  cacheAvailablePackageNames: (packages) ->
    @availablePackageCache = []
    for packageType in ['core', 'user', 'dev', 'git']
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
