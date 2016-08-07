_ = require 'underscore-plus'
semver = require 'semver'
{Emitter, CompositeDisposable} = require 'atom'

module.exports =
class Package
  # Provides an Object out of a raw JSON from an apm result
  #
  # * `pkg` Object to initialize the package
  # * `@pkgManager` which handles the {Package}
  #
  constructor: (pkg, @pkgManager) ->
    _.extend(this, pkg)

    @type = if @theme then 'theme' else 'package'
    @repository ?= @metadata?.repository
    @version ?= pkg.metadata?.version
    @latestVersion ?= pkg.metadata?.latestVersion ? @version

    @emitter = new Emitter()

    @observeAtomPackages()

  # Public: Installs the package for atom and enables it if it was disabled before
  #
  # Returns a {Promise}
  install: ->
    @pkgManager.install(this)

  # Public: Updates the package for atom
  #
  # Returns a {Promise}
  update: ->
    @pkgManager.update(this, @newerVersion())

  # Public: Uninstalls the package from atom
  #
  # Returns a {Promise}
  uninstall: ->
    @pkgManager.uninstall(this)

  installAlternative: ->
    metadata = @getDeprecatedMetadata()
    loadedPack = atom.packages.getLoadedPackage(metadata?.alternative)
    return unless metadata?.hasAlternative and metadata.alternative isnt 'core' and not loadedPack

    {alternative} = metadata
    @pkgManager.installAlternative this, new Package(alternative, @pkgManager)

  # Public: Gives back a https URL for the url found in @repository
  #
  # Returns a {String}
  repositoryUrl: ->
    return unless @repository

    repoUrl = if typeof(@repository) is "string"
      @repository
    else
      @repository.url

    return unless repoUrl

    if repoUrl.match 'git@github'
      repoName = repoUrl.split(':')[1]
      repoUrl = "https://github.com/#{repoName}"

    repoUrl.replace(/\.git$/, '').replace(/\/+$/, '').replace(/^git\+/, '')

  # Public: Extracts a login from the repository url
  #
  # TODO: When a package is a core package it should always be 'atom'
  #
  # Returns a {String}
  owner: ->
    if repoUrl = @repositoryUrl()
      loginRegex = /github\.com\/([\w-]+)\/.+/
      repoUrl.match(loginRegex)?[1] ? ''

  # Public: Gives back the GitHub avatar url
  #
  # Returns a {String}
  avatarUrl: ->
    "https://avatars.githubusercontent.com/#{@owner()}" if @owner()

  # Public: Requests an asset from the package managers asset cache
  #
  # Returns a {Promise} resolving with the local path
  avatar: ->
    if @avatarUrl()
      @pkgManager.asset(@avatarUrl())
    else
      Promise.resolve()

  # Loads additional metadata if none is found
  #
  # Returns a {Rp}
  loadMetadata: ->
    unless @metadata and @downloads and @stargazers_count
      @pkgManager.getPackageMetadata(this)
        .then (pack) =>
          _.extend(this, pack)
    else
      Promise.resolve(this)

  enable: ->
    atom.packages.enablePackage(@name)
    @emit('enabled')

  disable: ->
    atom.packages.disablePackage(@name)
    @emit('disabled')

  isDisabled: ->
    atom.packages.isPackageDisabled(@name)

  isTheme: ->
    @type is 'theme'

  isCompatible: ->
    version = atom.getVersion() if typeof atom.getVersion() is 'string'
    engine = @metadata?.engines?.atom ? '*'
    return false unless semver.validRange(engine)
    return semver.satisfies(version, engine)

  newerVersion: ->
    @latestVersion unless @latestVersion is @version

  newerSha: ->
    if @apmInstallSource?.type is 'git'
      @newSha ?= @latestSha unless @apmInstallSource.sha is @latestSha

  loadCompatibleVersion: ->
    @pkgManager.loadCompatiblePackageVersion(@name)

  getDeprecatedMetadata: ->
    atom.packages.getDeprecatedPackageMetadata(@name, @version)

  isInstalled: ->
    atom.packages.getAvailablePackageNames().indexOf(@name) > -1
    # atom.packages.isPackageLoaded(@name)

  isDeprecated: ->
    atom.packages.isDeprecatedPackage(@name, @version)

  hasSettings: ->
    grammars = atom.grammars.getGrammars() ? []
    for grammar in grammars when grammar.path
      return true if grammar.packageName is @name

    @activateConfig()
    schema = atom.config.getSchema(@name)
    schema? and (schema.type isnt 'any')

  activateConfig: ->
    # Package.activateConfig() is part of the Private package API and should not be used outside of core.
    loadedPack = atom.packages.isPackageLoaded(@name)
    if loadedPack and not atom.packages.isPackageActive(@name)
      loadedPack.activateConfig() if loadedPack.activateConfig

  observeAtomPackages: ->
    atom.packages.onDidDeactivatePackage (pack) =>
      @emit 'deactivated' if pack.name is @name

    atom.packages.onDidActivatePackage (pack) =>
      @emit 'activated' if pack.name is @name

    atom.config.onDidChange 'core.disabledPackages', =>
      @emit 'disabled'

  on: (selectors, callback) ->
    subscriptions = new CompositeDisposable()
    for selector in selectors.split(" ")
      subscriptions.add @emitter.on(selector, callback)
    subscriptions

  emit: (event) ->
    @emitter.emit(event)
