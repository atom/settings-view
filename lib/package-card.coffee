{$, View} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
{shell} = require 'electron'
marked = null
{ownerFromRepository} = require './utils'
Package = require './package'

module.exports =
class PackageCard extends View

  @content: (pack) ->
    displayName = (if pack.gitUrlInfo then pack.gitUrlInfo.project else pack.name) ? ''
    pack.description ?= ''

    @div class: 'package-card col-lg-8', =>
      @div outlet: 'statsContainer', class: 'stats pull-right', =>
        @span outlet: 'packageStars', class: 'stats-item', =>
          @span outlet: 'stargazerIcon', class: 'icon icon-star'
          @span outlet: 'stargazerCount', class: 'value'

        @span outlet: 'packageDownloads', class: 'stats-item', =>
          @span outlet: 'downloadIcon', class: 'icon icon-cloud-download'
          @span outlet: 'downloadCount', class: 'value'

      @div class: 'body', =>
        @h4 class: 'card-name', =>
          @a class: 'package-name', outlet: 'packageName', displayName
          @span ' '
          @span class: 'package-version', =>
            @span outlet: 'versionValue', class: 'value', String(pack.version)

          @span class: 'deprecation-badge highlight-warning inline-block', 'Deprecated'
        @span outlet: 'packageDescription', class: 'package-description', pack.description
        @div outlet: 'packageMessage', class: 'package-message'

      @div class: 'meta', =>
        @div outlet: 'metaUserContainer', class: 'meta-user', =>
          @a outlet: 'avatarLink', href: "https://atom.io/users/#{pack.owner()}", =>
            @img outlet: 'avatar', class: 'avatar', src: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7' # A transparent gif so there is no "broken border"
          @a outlet: 'loginLink', class: 'author', href: "https://atom.io/users/#{pack.owner()}", pack.owner()
        @div class: 'meta-controls', =>
          @div class: 'btn-toolbar', =>
            @div outlet: 'updateButtonGroup', class: 'btn-group', =>
              @button type: 'button', class: 'btn btn-info icon icon-cloud-download update-button', outlet: 'updateButton', 'Update'

            @div outlet: 'installAlternativeButtonGroup', class: 'btn-group', =>
              @button type: 'button', class: 'btn btn-info icon icon-cloud-download install-alternative-button', outlet: 'installAlternativeButton', 'Install Alternative'

            @div outlet: 'installButtonGroup', class: 'btn-group', =>
              @button type: 'button', class: 'btn btn-info icon icon-cloud-download install-button', outlet: 'installButton', 'Install'

            @div outlet: 'packageActionButtonGroup', class: 'btn-group', =>
              @button type: 'button', class: 'btn icon icon-gear settings', outlet: 'settingsButton', 'Settings'

              unless pack.isBundled()
                @button type: 'button', class: 'btn icon icon-trashcan uninstall-button', outlet: 'uninstallButton', 'Uninstall'

              @button type: 'button', class: 'btn icon icon-playback-pause enablement', outlet: 'enablementButton', =>
                @span class: 'disable-text', 'Disable'
              @button type: 'button', class: 'btn status-indicator', tabindex: -1, outlet: 'statusIndicator'

  initialize: (@package, @options = {}) ->
    @disposables = new CompositeDisposable()
    @compatiblePack = null
    @onSettingsView = @options.onSettingsView ? false

    # Default to displaying the download count
    unless @options.stats
      @options.stats = {
        downloads: true
      }

    @package.loadMetadata()
      .then =>
        @displayStatsOrGit()

    @package.avatar()
      .then (avatarPath) =>
        @avatar.attr 'src', "file://#{avatarPath}" if avatarPath

    @packageMessage.on 'click', 'a', ->
      href = @getAttribute('href')
      if href?.startsWith('atom:')
        atom.workspace.open(href)
        false

    @updateState()

    @handlePackageEvents()
    @handleButtonEvents()

  updateState: ->
    @updateInstalledState()
    @updateDisabledState()
    @updateSettingsState()
    @showCompatiblity()
    @updateDeprecatedState()
    @showUpdate()

  showUpdate: ->
    @versionValue.text(@package.version)

    if @package.newerVersion() or @package.newerSha()
      if @package.newerVersion()
        @updateButton.text("Update to #{@package.newerVersion()}")
      else if @package.newerSha()
        @updateButton.text("Update to #{@package.newerSha().substr(0, 8)}")

      @updateButtonGroup.show()
    else
      @updateButtonGroup.hide()

  # In case the package is not compatible it will try to load a compatible version and update the card
  showCompatiblity: ->
    unless @package.isCompatible()
      @installButton.hide()

      @package.loadCompatibleVersion()
        .then (pack) =>
          if packageVersion = pack?.version
            @versionValue.text(String(packageVersion))
            if packageVersion isnt @package.version
              @versionValue.addClass('text-warning')
              @packageMessage.addClass('text-warning')
              @packageMessage.text """
              Version #{packageVersion} is not the latest version available for this package, but it's the latest that is compatible with your version of Atom.
              """

            @compatiblePack = pack
            @installButton.show()
          else
            @compatiblePack = false
            @installButtonGroup.hide()
            @versionValue.addClass('text-error')
            @packageMessage.addClass('text-error')
            @packageMessage.append """
            There's no version of this package that is compatible with your Atom version. The version must satisfy #{@package.engines.atom}.
            """
            console.error("No available version compatible with the installed Atom version: #{atom.getVersion()}")

  handleButtonEvents: ->
    @on 'click', =>
      @parents('.settings-view').view()?.showPanel(@package.name, {back: @options.back, pack: @package})
    @settingsButton.on 'click', (event) =>
      event.stopPropagation()
      @parents('.settings-view').view()?.showPanel(@package.name, {back: @options.back, pack: @package})

    @installButton.on 'click', (event) =>
      event.stopPropagation()
      if @compatiblePack
        @compatiblePack.install()
      else
        @package.install()

    if @uninstallButton
      @uninstallButton.on 'click', (event) =>
        event.stopPropagation()
        @package.uninstall()

    @installAlternativeButton.on 'click', (event) =>
      event.stopPropagation()
      @package.installAlternative()

    @updateButton.on 'click', (event) =>
      event.stopPropagation()
      @package.update()

    @packageName.on 'click', (event) =>
      event.stopPropagation()
      shell.openExternal("https://atom.io/#{@package.type}/#{@package.name}")

    if @enablementButton
      @enablementButton.on 'click', =>
        if @package.isDisabled()
          @package.enable()
        else
          @package.disable()
        false

  dispose: ->
    @disposables.dispose()

  updateInterfaceState: ->
    if @package.apmInstallSource?.type is 'git'
      @downloadCount.text @package.apmInstallSource.sha.substr(0, 8)

    @updateSettingsState()
    @updateInstalledState()
    @updateDisabledState() if @enablementButton
    @updateDeprecatedState()

  updateSettingsState: ->
    if @package.hasSettings() and not @onSettingsView
      @settingsButton.show()
    else
      @settingsButton.hide()

  # Section: disabled state updates

  updateDisabledState: ->
    if @enablementButton
      if @package.isDisabled()
        @displayDisabledState()
      else
        @displayEnabledState()

  displayEnabledState: ->
    @removeClass('disabled')

    if @package.isTheme()
      @enablementButton.hide()
      @statusIndicator.hide()
    else
      @enablementButton.find('.disable-text').text('Disable')
      @enablementButton
        .addClass('icon-playback-pause')
        .removeClass('icon-playback-play')
      @statusIndicator
        .removeClass('is-disabled')
      @enablementButton.show()
      @statusIndicator.show()

  displayDisabledState: ->
    @addClass('disabled')
    @enablementButton.find('.disable-text').text('Enable')
    @enablementButton
      .addClass('icon-playback-play')
      .removeClass('icon-playback-pause')
    @statusIndicator
      .addClass('is-disabled')

    if @package.isDeprecated()
      @enablementButton.prop('disabled', true)
    else
      @enablementButton.prop('disabled', false)

  # Section: installed state updates
  updateInstalledState: ->
    if @package.isInstalled()
      @displayInstalledState()
    else
      @displayNotInstalledState()

  displayInstalledState: ->
    @installButtonGroup.hide()
    @packageActionButtonGroup.show()
    @uninstallButton?.show()
    @installAlternativeButton.hide()

  displayNotInstalledState: ->
    @installButtonGroup.show()
    @packageActionButtonGroup.hide()
    @installAlternativeButton.hide()
    @uninstallButton?.hide()

  # Section: deprecated state updates
  updateDeprecatedState: ->
    if @package.isDeprecated()
      @displayDeprecatedState()
    else
      @displayUndeprecatedState()

  displayUndeprecatedState: ->
    @removeClass('deprecated')
    @packageMessage.removeClass('text-warning')
    @packageMessage.text('')


  #
  # hasDeprecations, no update: disabled-settings, uninstall, disable
  # hasDeprecations, has update: update, disabled-settings, uninstall, disable
  # hasAlternative; core: uninstall
  # hasAlternative; package, alt not installed: install new-package
  # hasAlternative; package, alt installed: uninstall
  #
  displayDeprecatedState: ->
    @addClass('deprecated')
    @settingsButton[0].disabled = true
    @installAlternativeButton.hide()

    info = @package.getDeprecatedMetadata()
    @packageMessage.addClass('text-warning')

    message = null
    if info?.hasDeprecations
      message = @getDeprecationPackageMessage()
    else if info?.hasAlternative and info?.alternative and info?.alternative is 'core'
      message = info.message ? "The features in `#{@package.name}` have been added to core."
      message += ' Please uninstall this package.'
      @uninstallButton.show()
      @settingsButton.remove()
      @enablementButton.remove()
      @installAlternativeButton.hide()
    else if info?.hasAlternative and alt = info?.alternative
      isInstalled = @package.isInstalled()
      alt = @package.alternative()

      @installAlternativeButton.show()

      if isInstalled and alt.isInstalled()
        message = "`#{@package.name}` has been replaced by `#{alt.name}` which is already installed. Please uninstall this package."
        @settingsButton.remove()
        @enablementButton.remove()
        @installAlternativeButton.hide()
      else if isInstalled
        message = "`#{@package.name}` has been replaced by [`#{alt.name}`](atom://config/install/package:#{alt.name})."
        @installAlternativeButton.text "Install #{alt.name}"
        @packageActionButtonGroup.show()
        @settingsButton.remove()
        @enablementButton.remove()
      else
        message = "`#{@package.name}` has been replaced by [`#{alt.name}`](atom://config/install/package:#{alt.name})."
        @installButtonGroup.hide()
        @installAlternativeButton.hide()
        @packageActionButtonGroup.hide()

    if message?
      marked ?= require 'marked'
      @packageMessage.html marked(message)

  displayStatsOrGit: ->
    if @package.apmInstallSource?.type is 'git'
      @downloadIcon.removeClass('icon-cloud-download')
      @downloadIcon.addClass('icon-git-branch')
      @downloadCount.text @package.apmInstallSource.sha.substr(0, 8)
    else
      if @options.stats?.downloads
        @downloadCount.text @package.downloads?.toLocaleString()
        @packageDownloads.show()
      else
        @packageDownloads.hide()

      if @options.stats?.stars
        @stargazerCount.text @package.stargazers_count?.toLocaleString()
        @packageStars.show()
      else
        @packageStars.hide()

  displayGitPackageInstallInformation: ->
    @metaUserContainer.remove()
    @statsContainer.remove()
    {gitUrlInfo} = @package
    if gitUrlInfo.default is 'shortcut'
      @packageDescription.text gitUrlInfo.https()
    else
      @packageDescription.text gitUrlInfo.toString()
    @installButton.removeClass('icon-cloud-download')
    @installButton.addClass('icon-git-commit')
    @updateButton.removeClass('icon-cloud-download')
    @updateButton.addClass('icon-git-commit')

  getDeprecationPackageMessage: ->
    info = @package.getDeprecatedMetadata()

    if newerPackage = @package.newerPackage()
      if newerPackage.hasDeprecations()
        "An update to `v#{@package.newerVersion()}` is available but still contains deprecations."
      else
        "An update to `v#{@package.newerVersion()}` is available without deprecations."
    else
      if @package.isInstalled()
        info.message ? 'This package has not been loaded due to using deprecated APIs. There is no update available.'
      else
        'This package has deprecations and is not installable.'

  handlePackageEvents: ->
    @disposables.add @package.on 'activated deactivated enabled disabled', =>
      @updateState()

    @disposables.add @package.on 'installing updating', =>
      @updateState()
      @updateButton.prop('disabled', true)
      @updateButton.addClass('is-installing')
      @installButton.prop('disabled', true)
      @installButton.addClass('is-installing')

    @disposables.add @package.on 'installing-alternative', =>
      @updateState()
      @installAlternativeButton.prop('disabled', true)
      @installAlternativeButton.addClass('is-installing')

    @disposables.add @package.on 'uninstalling', =>
      @updateState()
      @enablementButton.prop('disabled', true)
      @uninstallButton.prop('disabled', true)
      @uninstallButton.addClass('is-uninstalling')

    @disposables.add @package.on 'installed install-failed', =>
      @package.version = version if version = atom.packages.getLoadedPackage(@package.name)?.metadata?.version
      @installButton.prop('disabled', false)
      @installButton.removeClass('is-installing')
      @updateState()

    @disposables.add @package.on 'updated update-failed', =>
      metadata = atom.packages.getLoadedPackage(@package.name)?.metadata
      @package.version = version if version = metadata?.version
      @package.apmInstallSource = apmInstallSource if apmInstallSource = metadata?.apmInstallSource
      @updateButton.prop('disabled', false)
      @updateButton.removeClass('is-installing')

      @updateState()

    @disposables.add @package.on 'uninstalled uninstall-failed', =>
      @enablementButton.prop('disabled', false)
      @uninstallButton.prop('disabled', false)
      @uninstallButton.removeClass('is-uninstalling')
      @updateState()

    @disposables.add @package.on 'installed-alternative install-alternative-failed', =>
      @installAlternativeButton.prop('disabled', false)
      @installAlternativeButton.removeClass('is-installing')
      @updateState()
