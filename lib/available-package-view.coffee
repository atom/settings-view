_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'
{Subscriber} = require 'emissary'
shell = require 'shell'

module.exports =
class AvailablePackageView extends View
  Subscriber.includeInto(this)

  @content: ({name, description, version, repository}) ->
    # stars, downloads
    # lol wat
    owner = AvailablePackageView::ownerFromRepository(repository)
    description ?= ''

    @div class: 'available-package-view col-lg-8', =>
      @div class: 'stats pull-right', =>
        @span class: "stats-item", =>
          @span class: 'icon icon-versions'
          @span outlet: 'versionValue', class:'value', String(version)

        @span class: 'stats-item', =>
          @span class: 'icon icon-cloud-download'
          @span outlet: 'downloadCount', class: 'value'

      @div class: 'body', =>
        @h4 class: 'card-name', =>
          @a outlet: 'packageName', name
        @span outlet: 'packageDescription', class: 'package-description', description

      @div class: 'meta', =>
        @div class: 'meta-user', =>
          @a outlet: 'avatarLink', href: "https://atom.io/users/#{owner}", =>
            @img outlet: 'avatar', class: 'avatar', src: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7' # A transparent gif so there is no "broken border"
          @a outlet: 'loginLink', class: 'author', href: "https://atom.io/users/#{owner}", owner
        @div class: 'meta-controls', =>
          @div class: 'btn-group', =>
            @button type: 'button', class: 'btn btn-info icon icon-cloud-download install-button', outlet: 'installButton', 'Install'
          @div outlet: 'buttons', class: 'btn-group', =>
            @button type: 'button', class: 'btn icon icon-gear',           outlet: 'settingsButton', 'Settings'
            @button type: 'button', class: 'btn icon icon-trashcan',       outlet: 'uninstallButton', 'Uninstall'
            @button type: 'button', class: 'btn icon icon-playback-pause', outlet: 'enablementButton', =>
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
    @updateEnablement()
    @loadCachedMetadata()

    # We hide install/uninstall buttons until we know how to treat this
    # package.
    @installButton.hide()
    @uninstallButton.hide()

    # The package is bundled with Atom, we don't need to do anything
    # beyond that.
    return if atom.packages.isBundledPackage(@pack.name)

    # The package is not bundled with Atom, but is already installed
    # we only need to show the uninstall button.
    if @isInstalled()
      @uninstallButton.show()
    # The package is not bundled with Atom and is not installed so we'll have
    # to find a package version that is compatible with this Atom version.
    else
      @packageManager.requestPackage @pack.name, (err, pack) =>
        if err?
          console.error(err)
        else
          packageVersion = @packageManager.getLatestCompatibleVersion(pack)
          # A compatible version exist, we activate the install button and
          # replace @pack so that the install action installs the compatible
          # version of the package.
          if packageVersion
            @versionValue.text(packageVersion)
            if packageVersion isnt @pack.version
              @versionValue.addClass('text-warning')
              @packageDescription.append """
              <br/>
              <span class='text-warning'>
                Version #{packageVersion} is not the latest version available for this package, but it's the latest that is compatible with your version of Atom.
              </span>
              """

            @pack = pack.versions[packageVersion]
            @installButton.show()
          else
            @versionValue.addClass('text-danger')
            @packageDescription.append """
            <br/>
            <span class='text-danger'>
              There's no version of this package that is compatible with your Atom version. The version must satisfy #{@pack.engines.atom}.
            </span>
            """
            console.error("No available version compatible with the installed Atom version: #{atom.getVersion()}")
            return

    @installButton.on 'click', =>
      @install()

    @uninstallButton.on 'click', =>
      @uninstall()

    @settingsButton.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name, {back: opts?.back})

    @packageName.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name, {back: opts?.back})

    @enablementButton.on 'click', =>
      if @isDisabled()
        atom.packages.enablePackage(@pack.name)
      else
        atom.packages.disablePackage(@pack.name)
      @updateEnablement()
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

    if atom.packages.isPackageDisabled(@pack.name)
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

  subscribeToPackageEvent: (event, callback) ->
    @subscribe @packageManager, event, (pack, error) =>
      callback(pack, error) if pack.name is @pack.name

  install: ->
    @installButton.addClass('is-installing')
    @packageManager.emit('package-installing', @pack)
    @packageManager.install @pack, (error) =>
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
