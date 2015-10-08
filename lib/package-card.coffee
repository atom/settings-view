_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
shell = require 'shell'
marked = null
{ownerFromRepository} = require './utils'

module.exports =
class PackageCard extends View

  @content: ({name, description, version, repository}) ->
    owner = ownerFromRepository(repository)
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
              @button type: 'button', class: 'btn icon icon-trashcan uninstall-button', outlet: 'uninstallButton', 'Uninstall'
              @button type: 'button', class: 'btn icon icon-playback-pause enablement', outlet: 'enablementButton', =>
                @span class: 'disable-text', 'Disable'
              @button type: 'button', class: 'btn status-indicator', tabindex: -1, outlet: 'statusIndicator'

  initialize: (@pack, @packageManager, options) ->
    @disposables = new CompositeDisposable()

    # It might be useful to either wrap @pack in a class that has a ::validate
    # method, or add a method here. At the moment I think all cases of malformed
    # package metadata are handled here and in ::content but belt and suspenders,
    # you know
    @client = @packageManager.getClient()

    @type = if @pack.theme then 'theme' else 'package'

    {@name} = @pack

    @newVersion = @pack.latestVersion unless @pack.latestVersion is @pack.version

    @handlePackageEvents()
    @handleButtonEvents(options)
    @loadCachedMetadata()

    @packageMessage.on 'click', 'a', ->
      href = @getAttribute('href')
      if href?.startsWith('atom:')
        atom.workspace.open(href)
        false

    # themes have no status and cannot be dis/enabled
    if @type is 'theme'
      @statusIndicator.remove()
      @enablementButton.remove()

    @settingsButton.remove() unless @hasSettings()
    if atom.packages.isBundledPackage(@pack.name)
      @installButtonGroup.remove()
      @uninstallButton.remove()

    @updateButtonGroup.hide() unless @newVersion

    @hasCompatibleVersion = true
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
          @hasCompatibleVersion = false
          @installButtonGroup.hide()
          @versionValue.addClass('text-error')
          @packageMessage.addClass('text-error')
          @packageMessage.append """
          There's no version of this package that is compatible with your Atom version. The version must satisfy #{@pack.engines.atom}.
          """
          console.error("No available version compatible with the installed Atom version: #{atom.getVersion()}")

  handleButtonEvents: (options) ->
    if options?.onSettingsView
      @settingsButton.remove()
    else
      @on 'click', =>
        @parents('.settings-view').view()?.showPanel(@pack.name, {back: options?.back, pack: @pack})
      @settingsButton.on 'click', (event) =>
        event.stopPropagation()
        @parents('.settings-view').view()?.showPanel(@pack.name, {back: options?.back, pack: @pack})

    @installButton.on 'click', (event) =>
      event.stopPropagation()
      @install()

    @uninstallButton.on 'click', (event) =>
      event.stopPropagation()
      @uninstall()

    @installAlternativeButton.on 'click', (event) =>
      event.stopPropagation()
      @installAlternative()

    @updateButton.on 'click', (event) =>
      event.stopPropagation()
      @update()

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

  dispose: ->
    @disposables.dispose()

  loadCachedMetadata: ->
    @client.avatar ownerFromRepository(@pack.repository), (err, avatarPath) =>
      @avatar.attr 'src', "file://#{avatarPath}" if avatarPath

    @client.package @pack.name, (err, data) =>
      # We don't need to actually handle the error here, we can just skip
      # showing the download count if there's a problem.
      unless err
        data ?= {}
        @downloadCount.text data.downloads?.toLocaleString()

  updateInterfaceState: ->
    @versionValue.text(@installablePack?.version ? @pack.version)
    @updateInstalledState()
    @updateDisabledState()
    @updateDeprecatedState()

  # Section: disabled state updates

  updateDisabledState: ->
    if @isDisabled()
      @displayDisabledState()
    else if @hasClass('disabled')
      @displayEnabledState()

  displayEnabledState: ->
    @removeClass('disabled')
    @enablementButton.hide() if @type is 'theme'
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

    if @isDeprecated()
      @enablementButton.prop('disabled', true)
    else
      @enablementButton.prop('disabled', false)

  # Section: installed state updates

  updateInstalledState: ->
    if @isInstalled()
      @displayInstalledState()
    else
      @displayNotInstalledState()

  displayInstalledState: ->
    if @newVersion
      @updateButtonGroup.show()
      @updateButton.text("Update to #{@newVersion}")
    else
      @updateButtonGroup.hide()

    @installButtonGroup.hide()
    @installAlternativeButtonGroup.hide()
    @packageActionButtonGroup.show()
    @uninstallButton.show()

  displayNotInstalledState: ->
    if not @hasCompatibleVersion
      @installButtonGroup.hide()
      @updateButtonGroup.hide()
    else if @newVersion
      @updateButtonGroup.show()
      @installButtonGroup.hide()
    else
      @updateButtonGroup.hide()
      @installButtonGroup.show()
    @installAlternativeButtonGroup.hide()
    @packageActionButtonGroup.hide()

  # Section: deprecated state updates

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

    info = @getDeprecatedPackageMetadata()
    @packageMessage.addClass('text-warning')

    message = null
    if info?.hasDeprecations
      message = @getDeprecationMessage(@newVersion)
    else if info?.hasAlternative and info?.alternative and info?.alternative is 'core'
      message = info.message ? "The features in `#{@pack.name}` have been added to core."
      message += ' Please uninstall this package.'
      @settingsButton.remove()
      @enablementButton.remove()
    else if info?.hasAlternative and alt = info?.alternative
      isInstalled = @isInstalled()
      if isInstalled and @packageManager.isPackageInstalled(alt)
        message = "`#{@pack.name}` has been replaced by `#{alt}` which is already installed. Please uninstall this package."
        @settingsButton.remove()
        @enablementButton.remove()
      else if isInstalled
        message = "`#{@pack.name}` has been replaced by [`#{alt}`](atom://config/install/package:#{alt})."
        @installAlternativeButton.text "Install #{alt}"
        @installAlternativeButtonGroup.show()
        @packageActionButtonGroup.show()
        @settingsButton.remove()
        @enablementButton.remove()
      else
        message = "`#{@pack.name}` has been replaced by [`#{alt}`](atom://config/install/package:#{alt})."
        @installButtonGroup.hide()
        @installAlternativeButtonGroup.hide()
        @packageActionButtonGroup.hide()

    if message?
      marked ?= require 'marked'
      @packageMessage.html marked(message)

  displayAvailableUpdate: (@newVersion) ->
    @updateInterfaceState()

  getDeprecationMessage: (newVersion) ->
    info = @getDeprecatedPackageMetadata()
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
    @disposables.add atom.packages.onDidDeactivatePackage (pack) =>
      @updateDisabledState() if pack.name is @pack.name

    @disposables.add atom.packages.onDidActivatePackage (pack) =>
      @updateDisabledState() if pack.name is @pack.name

    @disposables.add atom.config.onDidChange 'core.disabledPackages', =>
      @updateDisabledState()

    @subscribeToPackageEvent 'package-installing theme-installing', =>
      @updateInterfaceState()
      @installButton.prop('disabled', true)
      @installButton.addClass('is-installing')

    @subscribeToPackageEvent 'package-updating theme-updating', =>
      @updateInterfaceState()
      @updateButton.prop('disabled', true)
      @updateButton.addClass('is-installing')

    @subscribeToPackageEvent 'package-installing-alternative', =>
      @updateInterfaceState()
      @installAlternativeButton.prop('disabled', true)
      @installAlternativeButton.addClass('is-installing')

    @subscribeToPackageEvent 'package-uninstalling theme-uninstalling', =>
      @updateInterfaceState()
      @enablementButton.prop('disabled', true)
      @uninstallButton.prop('disabled', true)
      @uninstallButton.addClass('is-uninstalling')

    @subscribeToPackageEvent 'package-installed package-install-failed theme-installed theme-install-failed', =>
      @pack.version = version if version = atom.packages.getLoadedPackage(@pack.name)?.metadata?.version
      @installButton.prop('disabled', false)
      @installButton.removeClass('is-installing')
      @updateInterfaceState()

    @subscribeToPackageEvent 'package-updated theme-updated package-update-failed theme-update-failed', =>
      @pack.version = version if version = atom.packages.getLoadedPackage(@pack.name)?.metadata?.version
      @newVersion = null
      @updateButton.prop('disabled', false)
      @updateButton.removeClass('is-installing')
      @updateInterfaceState()

    @subscribeToPackageEvent 'package-uninstalled package-uninstall-failed theme-uninstalled theme-uninstall-failed', =>
      @newVersion = null
      @enablementButton.prop('disabled', false)
      @uninstallButton.prop('disabled', false)
      @uninstallButton.removeClass('is-uninstalling')
      @updateInterfaceState()

    @subscribeToPackageEvent 'package-installed-alternative package-install-alternative-failed', =>
      @installAlternativeButton.prop('disabled', false)
      @installAlternativeButton.removeClass('is-installing')
      @updateInterfaceState()

  isInstalled: -> @packageManager.isPackageInstalled(@pack.name)

  isDisabled: -> atom.packages.isPackageDisabled(@pack.name)

  isDeprecated: (version) -> atom.packages.isDeprecatedPackage(@pack.name, version ? @pack.version)

  getDeprecatedPackageMetadata: -> atom.packages.getDeprecatedPackageMetadata(@pack.name)

  hasSettings: -> @packageManager.packageHasSettings(@pack.name)

  subscribeToPackageEvent: (event, callback) ->
    @disposables.add @packageManager.on event, ({pack, error}) =>
      packageName = pack.name
      packageName = pack.pack.name if pack.pack?
      callback(pack, error) if packageName is @pack.name

  ###
  Section: Methods that should be on a Package model
  ###

  install: ->
    @packageManager.install @installablePack ? @pack, (error) =>
      if error?
        console.error("Installing #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)
      else
        # if a package was disabled before installing it, re-enable it
        atom.packages.enablePackage(@pack.name) if @isDisabled()

  update: ->
    return unless @newVersion
    @packageManager.update @installablePack ? @pack, @newVersion, (error) =>
      if error?
        console.error("Updating #{@type} #{@pack.name} to v#{@newVersion} failed", error.stack ? error, error.stderr)

  uninstall: ->
    @packageManager.uninstall @pack, (error) =>
      if error?
        console.error("Uninstalling #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)

  installAlternative: ->
    metadata = @getDeprecatedPackageMetadata()
    loadedPack = atom.packages.getLoadedPackage(metadata?.alternative)
    return unless metadata?.hasAlternative and metadata.alternative isnt 'core' and not loadedPack

    {alternative} = metadata
    @packageManager.installAlternative @pack, alternative, (error, {pack, alternative}) =>
      if error?
        console.error("Installing alternative `#{alternative}` #{@type} for #{@pack.name} failed", error.stack ? error, error.stderr)
