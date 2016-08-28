_ = require 'underscore-plus'
{BufferedProcess, CompositeDisposable, Emitter} = require 'atom'
semver = require 'semver'
request = require 'request'

List = require './list'
Package = require './package'
CachedAssets = require './cached-assets'

DefaultRequestHeaders = {'User-Agent': navigator.userAgent}

module.exports =
class PackageManager
  PACKAGE_LISTS: {
    "installed:packages": ['ls', '--packages'],
    "installed:themes": ['ls', '--themes'],
    "outdated": ['outdated', 'compatible'],
    "featured:packages": ['featured', 'compatible'],
    "featured:themes": ['featured', '--themes', 'compatible']
  }

  constructor: ->
    @emitter = new Emitter
    @storageKey = "settings-view:package-store"
    @cachedLists = {}
    @cachedPackages = {}
    @assetCache ?= new CachedAssets()

    @on 'package-installed package-updated package-updated-failed package-install-failed package-uninstalled package-uninstall-failed', =>
      Promise.all([
        @clearStoredList('installed:packages'),
        @clearStoredList('installed:themes'),
        @clearStoredList('outdated')
      ]).then =>
        @reloadCachedLists()

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
      'downloads', 'stargazers_count', 'repository', 'theme'
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

  # Public: Retrieves a Package from localStorage
  #
  # * `packName` {String}
  #
  # Returns an {Object}
  storedPackage: (packName) ->
    stored = localStorage.getItem("#{@storageKey}:package:#{packName}")
    JSON.parse(stored) if stored

  # Gets a {Package} from the package object cache (@cachedPackages) or puts it in
  #
  # * `pack` {Package} to be cached
  #
  # Returns {Package}
  cachedPackage: (pack) ->
    if cachedPackage = @cachedPackages[pack.name]
      _.extend cachedPackage, pack
    else
      @cachedPackages[pack.name] = new Package pack, this

  # Public: Stores a lists packages to localStorage
  #
  # * `listName` {String}
  # * `result` {Array} of {Package}s
  #
  # Returns an {Object}
  storeList: (listName, result) ->
    packages = []
    newResult = null

    unless _.isArray(result)
      newResult = {}
      _.each result, (packageList, key) =>
        newResult[key] = @listResultToPackageNames(packageList)
        packages.push(packageList)
    else
      newResult = @listResultToPackageNames(result)
      packages.push(result)

    packages = _.flatten packages
    Promise.all _.map packages, (pack) =>
      @storePackage(pack)
    .then =>
      localStorage.removeItem(@storeKeyForList(listName))
      localStorage.setItem(@storeKeyForList(listName), JSON.stringify(newResult))
      @storedList(listName)

  # Public: Retrieves a list and returns them as {Package}s
  #
  # * `listName` {String}
  #
  # Returns an {Object}
  storedList: (listName) ->
    listKey = @storeKeyForList(listName)
    stored = localStorage.getItem(listKey)
    stored = if stored then JSON.parse(stored)

    if stored
      unless _.isArray(stored)
        _.each stored, (packageList, key) =>
          stored[key] = _.map packageList, (packName) =>
            @storedPackage(packName)
      else
        stored = _.map stored, (packName) =>
          @storedPackage(packName)

    stored

  # Takes a list of raw package objects and initializes Package instances for them
  listResultToPackages: (packages) ->
    _.map packages, (pack) =>
      @cachedPackage pack

  # Takes a list of raw package objects and initializes Package instances for them
  listResultToPackageNames: (packages) ->
    _.map packages, (pack) ->
      pack.name

  # Gets a {List} from the list object cache (@cachedLists) or puts it in
  #
  # * `listName` {String}
  # * `packages` {Array} or {Object} of {Package}s
  #
  # Returns a {List} or an {Object} with {List}s
  cachedList: (listName, packages) ->
    listKey = @storeKeyForList(listName)

    unless _.isArray(packages)
      _.each packages, (packageList, key) =>
        @cachedLists[listName] ?= {}
        @cachedLists[listName][key] ?= new List('name')
        @cachedLists[listName][key].setItems(@listResultToPackages(packageList))
    else
      @cachedLists[listName] ?= new List('name')
      @cachedLists[listName].setItems(@listResultToPackages(packages))

    @cachedLists[listName]

  # Public:  Looks up list arguments in PACKAGE_LISTS
  # When a arguments for a list contain the `compatible` flag it'll push the command arguments for it in.
  #
  # * `listName` {String} in the format of `LIST[:SUB-LIST]`
  #
  # Returns a {Promise} resolving with an {Array} of arguments
  getListArguments: (listName) ->
    new Promise (resolve, reject) =>
      if args = @PACKAGE_LISTS[listName]
        resolve(args)
      else
        reject(new Error("Arguments for package list not found"))
    .then (args) ->
      args = _.clone(args)
      if args.indexOf('compatible') > -1
        args.splice(args.indexOf('compatible'), 1)
        version = atom.getVersion()
        args.push('--compatible', version) if semver.valid(version)

      args

  # Public: Looks up a list and returns it.
  #
  # When a list is not already stored it gets, stores and returns it
  # When it is found it returns it and refreshes the List async
  #
  # * `listName` {String} in the format of `LIST[:SUB-LIST]`
  #
  # Returns a {Promise} resolving with {Package} objects in a {List}
  getPackageList: (listName) ->
    Promise.resolve()
      .then =>
        if result = @storedList(listName)
          result
        else
          @getJSONListResult(listName)
            .then (result) =>
              @storeList(listName, result)
      .then (packages) =>
        @cachedList(listName, packages)

  getJSONListResult: (listName) ->
    @getListArguments(listName)
      .then (args) =>
        @jsonCommand(args, "Fetching results for #{listName} failed")

  clearStoredList: (listName) ->
    localStorage.removeItem("#{@storeKeyForList(listName)}")
    Promise.resolve(listName)

  reloadCachedLists: ->
    lists = _.keys @cachedLists
    _.each lists, (listName) =>
      @clearStoredList(listName)
        .then => @getPackageList(listName)
        .catch ->
          console.warn "Failed to reload #{listName}"

  request: (url, callback) ->
    options = {
      url: url
      headers: DefaultRequestHeaders
    }

    new Promise (resolve, reject) ->
      request options, (err, res, body) ->
        reject(err) if err
        resolve(body)

  getAtomPackagesUrl: ->
    process.env.ATOM_PACKAGES_URL ? "#{@getAtomApiUrl()}/packages"

  getAtomApiUrl: ->
    process.env.ATOM_API_URL ? 'https://atom.io/api'

  getPackageMetadata: (pack) ->
    @request("#{@getAtomPackagesUrl()}/#{pack.name}")
        .then @parseJSON
        .then (packJson) =>
          _.extend pack, packJson
          @storePackage(packJson)

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

  loadCompatiblePackageVersion: (packageName) ->
    args = ['view', packageName, '--compatible', @normalizeVersion(atom.getVersion())]
    errorMessage = "Fetching package '#{packageName}' failed."

    @jsonCommand(args, errorMessage)
      .then (pack) =>
        @cachedPackage(pack)

  view: (packageName) ->
    args = ['view', packageName]
    errorMessage = "Fetching package '#{packageName}' failed."

    @jsonCommand(args, errorMessage)

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
      .then (packages) =>
        packages = _.map packages, (pack) =>
          @cachedPackage(pack)
        packages

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
        pack.emit 'updating'
        @emit 'package-updating', pack
        @command(args, errorMessage)
      .then =>
        pack.version = newVersion
        pack.latestVersion = null

        activation = if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        Promise.resolve(activation).then =>
          @emit 'package-updated', pack
          pack.emit 'updated'

      .catch (error) =>
        atom.packages.activatePackage(name) if activateOnFailure

        error = new Error(errorMessage)
        error.packageInstallError = not theme
        @emit 'package-updated-failed', pack, error
        pack.emit 'update-failed', error

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
        pack.emit 'installing'
        @emit 'package-installing', pack
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

        @reloadCachedLists()

        pack.emit 'installed'
        @emit 'package-installed', pack

        pack
      .catch (error) =>
        console.error error
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error(errorMessage)
        error.packageInstallError = not theme

        @emit 'package-install-failed', pack, error
        pack.emit 'install-failed', error

  uninstall: (pack) ->
    {name} = pack
    args = ['uninstall', '--hard', name]
    errorMessage = "Uninstalling \u201C#{name}\u201D failed."

    @unload(name)
      .then =>
        pack.emit 'uninstalling'
        @command(args, errorMessage)
      .then =>
        @removePackageNameFromDisabledPackages(name)
        pack.emit 'uninstalled'
        @emitter.emit 'package-uninstalled', pack
      .catch (error) =>
        @emitter.emit 'package-uninstall-failed', error
        pack.emit 'uninstall-failed', error

  installAlternative: (pack, alternativePackage) ->
    eventArg = {pack, alternative: alternativePackage}
    pack.emit 'installing-alternative', eventArg

    uninstallPromise = @uninstall pack
    installPromise = @install(alternativePackage)

    Promise.all([uninstallPromise, installPromise])
      .then ->
        pack.emit 'installed-alternative', eventArg
      .catch (error) ->
        eventArg.error = error
        pack.emit 'install-alternative-failed', eventArg

  checkNativeBuildTools: ->
    @command(['install', '--check'])

  removePackageNameFromDisabledPackages: (packageName) ->
    atom.config.removeAtKeyPath('core.disabledPackages', packageName)

  # TODO: in case it is a package event and a package is given emit en event on the package
  emit: (args...) ->
    @emitter.emit(args)

  on: (selectors, callback) ->
    subscriptions = new CompositeDisposable
    for selector in selectors.split(" ")
      subscriptions.add @emitter.on(selector, callback)
    subscriptions
