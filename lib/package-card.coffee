_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'
{Subscriber} = require 'emissary'
shell = require 'shell'

module.exports =
class PackageCard extends View
  Subscriber.includeInto(this)

  @content: ({name, description, version, repository}) ->
    # stars, downloads
    # lol wat
    owner = PackageCard::ownerFromRepository(repository)
    description ?= ''

    @div class: 'package-card col-lg-8', =>
      @div class: 'stats pull-right', =>
        @span class: "stats-item", =>
          @span class: 'icon icon-versions'
          @span outlet: 'versionValue', class: 'value', String(version)

        @span class: 'stats-item', =>
          @span class: 'icon icon-cloud-download'
          @span outlet: 'downloadCount', class: 'value'

      @div class: 'body', =>
        @h4 class: 'card-name', =>
          @a outlet: 'packageName', name
          @span ' '
          @span class: 'deprecation-badge highlight-warning inline-block', 'Deprecated'
        @span outlet: 'packageDescription', class: 'package-description', description
        @div outlet: 'packageMessage', class: 'package-message'

      @div class: 'meta', =>
        @div class: 'meta-user', =>
          @a outlet: 'avatarLink', href: "https://atom.io/users/#{owner}", =>
            @img outlet: 'avatar', class: 'avatar', src: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7' # A transparent gif so there is no "broken border"
          @a outlet: 'loginLink', class: 'author', href: "https://atom.io/users/#{owner}", owner
        @div class: 'meta-controls', =>
          @div class: 'btn-group', =>
            @button type: 'button', class: 'btn btn-info icon icon-cloud-download install-button', outlet: 'installButton', 'Install'
          @div outlet: 'buttons', class: 'btn-group', =>
            @button type: 'button', class: 'btn icon icon-gear settings',             outlet: 'settingsButton', 'Settings'
            @button type: 'button', class: 'btn icon icon-trashcan uninstall',        outlet: 'uninstallButton', 'Uninstall'
            @button type: 'button', class: 'btn icon icon-playback-pause enablement', outlet: 'enablementButton', =>
              @span class: 'disable-text', 'Disable'
            @button type: 'button', class: 'btn status-indicator', tabindex: -1, outlet: 'statusIndicator'

  initialize: (@pack, @packageManager, opts) ->
    # It might be useful to either wrap @pack in a class that has a ::validate
    # method, or add a method here. At the moment I think all cases of malformed
    # package metadata are handled here and in ::content but belt and suspenders,
    # you know
    @client = @packageManager.getClient()

    @type = if @pack.theme then 'theme' else 'package'

    owner = @ownerFromRepository(@pack.repository)
    @filterText = "#{@pack.name} #{owner}"
    {@name} = @pack

    @handlePackageEvents()
    @handleControlsEvent(opts)
    @updateEnablement()
    @loadCachedMetadata()

    if atom.packages.isBundledPackage(@pack.name)
      @installButton.hide()
      @uninstallButton.hide()

    # themes have no status and cannot be dis/enabled
    if @type is 'theme'
      @statusIndicator.remove()
      @enablementButton.remove()

    unless @hasSettings(@pack)
      @settingsButton.remove()

    # The package is not bundled with Atom and is not installed so we'll have
    # to find a package version that is compatible with this Atom version.
    unless @isInstalled()
      @uninstallButton.hide()
      atomVersion = @packageManager.normalizeVersion(atom.getVersion())
      # The latest version is not compatible with the current Atom version,
      # we need to make a request to get the latest compatible version.
      unless @packageManager.satisfiesVersion(atomVersion, @pack)
        @packageManager.loadCompatiblePackageVersion @pack.name, (err, pack) =>
          return console.error(err) if err?

          packageVersion = pack.version

          # A compatible version exist, we activate the install button and
          # set @installablePack so that the install action installs the
          # compatible version of the package.
          if packageVersion
            @versionValue.text(packageVersion)
            if packageVersion isnt @pack.version
              @versionValue.addClass('text-warning')
              @packageMessage.addClass('text-warning')
              @packageMessage.text """
              Version #{packageVersion} is not the latest version available for this package, but it's the latest that is compatible with your version of Atom.
              """

            @installablePack = pack
          else
            @installButton.hide()
            @versionValue.addClass('text-error')
            @packageMessage.addClass('text-error')
            @packageMessage.append """
            There's no version of this package that is compatible with your Atom version. The version must satisfy #{@pack.engines.atom}.
            """
            console.error("No available version compatible with the installed Atom version: #{atom.getVersion()}")

    if @isDeprecated()
      marked = require 'marked'
      info = atom.packages.getPackageDeprecationInfo(pack.name)
      @packageMessage.addClass('text-warning')
      if info?.message
        @packageMessage.html marked(info.message)
      else if info?.hasDeprecations
        @packageMessage.text 'This package has deprecations. There may be an updated version without deprecations.'
      else if info?.hasAlternative and alt = info?.alternative
        if alt is 'core'
          @packageMessage.html marked("The features in `#{pack.name}` have been added to core. Please disable or uninstall this package.")
        else
          @packageMessage.html marked("`#{pack.name}` has been replaced by `#{alt}`. Please uninstall this package and install `#{alt}`.")

  handleControlsEvent: (opts) ->
    if opts?.onSettingsView
      @settingsButton.remove()
    else
      @on 'click', =>
        @parents('.settings-view').view()?.showPanel(@pack.name, {back: opts?.back, pack: @pack})
      @settingsButton.on 'click', (event) =>
        event.stopPropagation()
        @parents('.settings-view').view()?.showPanel(@pack.name, {back: opts?.back, pack: @pack})

    @installButton.on 'click', (event) =>
      event.stopPropagation()
      @install()

    @uninstallButton.on 'click', (event) =>
      event.stopPropagation()
      @uninstall()

    @packageName.on 'click', (event) =>
      event.stopPropagation()
      packageType = if @pack.theme then 'themes' else 'packages'
      shell.openExternal("https://atom.io/#{packageType}/#{@pack.name}")

    @enablementButton.on 'click', =>
      if @isDisabled()
        atom.packages.enablePackage(@pack.name)
      else
        atom.packages.disablePackage(@pack.name)
      false

  detached: ->
    @unsubscribe()

  ownerFromRepository: (repository) ->
    return '' unless repository
    loginRegex = /github\.com\/([\w-]+)\/.+/
    if typeof(repository) is "string"
      repo = repository
    else
      repo = repository.url
      if repo.match 'git@github'
        repoName = repo.split(':')[1]
        repo = "https://github.com/#{repoName}"
    repo.match(loginRegex)?[1] ? ''

  loadCachedMetadata: ->
    @client.avatar @ownerFromRepository(@pack.repository), (err, avatarPath) =>
      @avatar.attr 'src', "file://#{avatarPath}" if avatarPath

    @client.package @pack.name, (err, data) =>
      data ?= {}
      @packageData = data
      @downloadCount.text data.downloads?.toLocaleString()

  updateEnablement: ->
    if @type is 'theme'
      return @enablementButton.hide()

    if @isDeprecated()
      @addClass('deprecated')
    else
      @removeClass('deprecated')

    if @isDisabled()
      @addClass('disabled')
      @enablementButton.find('.disable-text').text('Enable')
      @enablementButton
        .addClass('icon-playback-play')
        .removeClass('icon-playback-pause')
      @statusIndicator
        .addClass('is-disabled')
    else
      @removeClass('disabled')
      @enablementButton.find('.disable-text').text('Disable')
      @enablementButton
        .addClass('icon-playback-pause')
        .removeClass('icon-playback-play')
      @statusIndicator
        .removeClass('is-disabled')

  handlePackageEvents: ->
    atom.packages.onDidDeactivatePackage (pack) =>
      @updateEnablement() if pack.name is @pack.name

    atom.packages.onDidActivatePackage (pack) =>
      @updateEnablement() if pack.name is @pack.name

    atom.config.onDidChange 'core.disabledPackages', =>
      @updateEnablement()

    @subscribeToPackageEvent 'package-installed package-install-failed theme-installed theme-install-failed', (pack, error) =>
      @installButton.prop('disabled', false)
      unless error?
        @updateEnablement()

        @installButton.hide()
        @uninstallButton.show()
        @settingsButton.show()
        @enablementButton.show()
        @statusIndicator.show()

    @subscribeToPackageEvent 'package-installing', (pack) =>
      @installButton.prop('disabled', true)
      @installButton.show()
      @uninstallButton.hide()

    @subscribeToPackageEvent 'package-uninstalling', (pack) =>
      @installButton.prop('disabled', true)

    @subscribeToPackageEvent 'package-uninstalled package-uninstall-failed theme-uninstalled theme-uninstall-failed', (pack, error) =>
      @installButton.prop('disabled', false)
      unless error?
        @installButton.show()
        @uninstallButton.hide()
        @settingsButton.hide()
        @enablementButton.hide()
        @statusIndicator.hide()

    if @isInstalled() or @isDisabled()
      @installButton.hide()
      @uninstallButton.show()
    else
      @settingsButton.hide()
      @uninstallButton.hide()
      @enablementButton.hide()
      @statusIndicator.hide()

  isInstalled: -> atom.packages.isPackageLoaded(@pack.name) and not atom.packages.isPackageDisabled(@pack.name)

  isDisabled: -> atom.packages.isPackageDisabled(@pack.name)

  isDeprecated: -> atom.packages.isPackageDeprecated(@pack.name)

  hasSettings: (pack) ->
    for key, value of atom.config.get(pack.name)
      return true
    false

  subscribeToPackageEvent: (event, callback) ->
    @subscribe @packageManager, event, (pack, error) =>
      callback(pack, error) if pack.name is @pack.name

  install: ->
    @installButton.addClass('is-installing')
    @packageManager.emit('package-installing', @installablePack ? @pack)
    @packageManager.install @installablePack ? @pack, (error) =>
      @installButton.removeClass('is-installing')
      if error?
        console.error("Installing #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)
      else
        # if a package was disabled before installing it, re-enable it
        if @isDisabled()
          atom.packages.enablePackage(@pack.name)

  uninstall: ->
    @packageManager.emit('package-uninstalling', @pack)
    @packageManager.uninstall @pack, (error) =>
      if error?
        console.error("Uninstalling #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)
