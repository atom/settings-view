_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'
{Subscriber} = require 'emissary'
shell = require 'shell'
marked = null

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
          @div class: 'btn-toolbar', =>
            @div outlet: 'updateButtonGroup', class: 'btn-group', =>
              @button type: 'button', class: 'btn btn-info icon icon-cloud-download install-button', outlet: 'updateButton', 'Update'
            @div outlet: 'installAlternativeButtonGroup', class: 'btn-group', =>
              @button type: 'button', class: 'btn btn-info icon icon-cloud-download install-button', outlet: 'installAlternativeButton', 'Install Alternative'
            @div outlet: 'installButtonGroup', class: 'btn-group', =>
              @button type: 'button', class: 'btn btn-info icon icon-cloud-download install-button', outlet: 'installButton', 'Install'
            @div outlet: 'packageActionButtonGroup', class: 'btn-group', =>
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
    @loadCachedMetadata()

    @packageMessage.on 'click', 'a', (e) ->
      if href = this.getAttribute('href') and href.startsWith('atom:')
        atom.workspace.open(href)
        false

    if atom.packages.isBundledPackage(@pack.name)
      @installButton.hide()
      @uninstallButton.hide()

    # themes have no status and cannot be dis/enabled
    if @type is 'theme'
      @statusIndicator.remove()
      @enablementButton.remove()

    unless @hasSettings(@pack)
      @settingsButton.remove()

    @updateButtonGroup.hide()
    @installAlternativeButtonGroup.hide()
    @enablementButton.hide() if @type is 'theme'

    @updateForUninstalledCommunityPackage() unless @isInstalled()
    @updateInterfaceState()

  updateForUninstalledCommunityPackage: ->
    # The package is not bundled with Atom and is not installed so we'll have
    # to find a package version that is compatible with this Atom version.

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
          @installButtonGroup.hide()
          @versionValue.addClass('text-error')
          @packageMessage.addClass('text-error')
          @packageMessage.append """
          There's no version of this package that is compatible with your Atom version. The version must satisfy #{@pack.engines.atom}.
          """
          console.error("No available version compatible with the installed Atom version: #{atom.getVersion()}")

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

  updateInterfaceState: ->
    @updateDisabledState()
    @updateDeprecatedState()

  updateDisabledState: ->
    if @isDisabled()
      @displayDisabledState()
    else if @hasClass('disabled')
      @displayEnabledState()

  displayEnabledState: ->
    @removeClass('disabled')
    @enablementButton.find('.disable-text').text('Disable')
    @enablementButton
      .addClass('icon-playback-pause')
      .removeClass('icon-playback-play')
    @statusIndicator
      .removeClass('is-disabled')

  displayDisabledState: ->
    @addClass('disabled')
    @enablementButton.find('.disable-text').text('Enable')
    @enablementButton
      .addClass('icon-playback-play')
      .removeClass('icon-playback-pause')
    @statusIndicator
      .addClass('is-disabled')

  updateDeprecatedState: ->
    if @isDeprecated()
      @displayDeprecatedState()
    else if @hasClass('deprecated')
      @displayUndeprecatedState()

  displayUndeprecatedState: ->
    @removeClass('deprecated')
    @packageMessage.removeClass('text-warning')
    @packageMessage.text('')

  displayDeprecatedState: ->
    @addClass('deprecated')
    @settingsButton[0].disabled = true

    info = @getPackageDeprecationMetadata()
    @packageMessage.addClass('text-warning')

    message = null
    if info?.hasDeprecations
      message = @getDeprecationMessage()
    else if info?.hasAlternative and info?.alternative and info?.alternative is 'core'
      message = info.message ? "The features in `#{@pack.name}` have been added to core."
      message += ' Please uninstall this package.'
      @settingsButton.remove()
      @enablementButton.remove()
    else if info?.hasAlternative and alt = info?.alternative
      if atom.packages.getLoadedPackage(alt)
        message = "`#{@pack.name}` has been replaced by `#{alt}` which is already installed. Please uninstall this package."
        @settingsButton.remove()
        @enablementButton.remove()
      else
        message = "`#{@pack.name}` has been replaced by [`#{alt}`](atom://config/install/package:#{alt})."
        @installAlternativeButton.text "Install #{alt}"
        @installAlternativeButtonGroup.show()
        @packageActionButtonGroup.hide()

    if message?
      marked ?= require 'marked'
      @packageMessage.html marked(message)

  displayAvailableUpdate: (newVersion) ->
    @updateButtonGroup.show()
    message = @getDeprecationMessage(newVersion)
    @packageMessage.html marked(message) if message?

  getDeprecationMessage: (newVersion) ->
    info = @getPackageDeprecationMetadata()
    return unless info?.hasDeprecations

    if newVersion
      if @isDeprecated(newVersion)
        "An update to `v#{newVersion}` is available but still contains deprecations."
      else
        "An update to `v#{newVersion}` is available without deprecations."
    else
      if @isInstalled()
        info.message ? 'This package has not been loaded due to using deprecated APIs. There is no update available.'
      else
        'This package has deprecations and is not installable.'

  handlePackageEvents: ->
    atom.packages.onDidDeactivatePackage (pack) =>
      @updateDisabledState() if pack.name is @pack.name

    atom.packages.onDidActivatePackage (pack) =>
      @updateDisabledState() if pack.name is @pack.name

    atom.config.onDidChange 'core.disabledPackages', =>
      @updateDisabledState()

    @subscribeToPackageEvent 'package-installed package-install-failed theme-installed theme-install-failed', (pack, error) =>
      @installButton.prop('disabled', false)
      unless error?
        @updateDisabledState()

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

  isDeprecated: (version) -> atom.packages.isPackageDeprecated(@pack.name, version ? @pack.version)

  getPackageDeprecationMetadata: -> atom.packages.getPackageDeprecationMetadata(@pack.name)

  hasSettings: (pack) ->
    for key, value of atom.config.get(pack.name)
      return true
    false

  subscribeToPackageEvent: (event, callback) ->
    @subscribe @packageManager, event, (pack, error) =>
      callback(pack, error) if pack.name is @pack.name

  ###
  Section: Methods that should be on a Package model
  ###

  install: ->
    @installButton.addClass('is-installing')
    # SKETCH: we shouldnt be emitting this event here
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
    # SKETCH: we shouldnt be emitting this event here
    @packageManager.emit('package-uninstalling', @pack)
    @packageManager.uninstall @pack, (error) =>
      if error?
        console.error("Uninstalling #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)
