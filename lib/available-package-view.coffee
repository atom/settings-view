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
      @div class: 'stats top-meta meta-right', =>
        @span class: "stats-item", =>
          @span class: 'icon icon-versions'
          @span class:'value', version

        @span class: 'stats-item', =>
          @span class: 'icon icon-cloud-download'
          @span outlet: 'downloadCount', class: 'value'

      @div class: 'body', =>
        @h4 class: 'card-name', =>
          @a outlet: 'packageName', name
        @span outlet: 'packageDescription', class: 'package-description', description

      @div class: 'meta', =>
        @a outlet: 'avatarLink', href: "https://atom.io/users/#{owner}", =>
          @img outlet: 'avatar', class: 'avatar', src: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7' # A transparent gif so there is no "broken border"
        @a outlet: 'loginLink', class: 'author', href: "https://atom.io/users/#{owner}", owner
        @div class: 'meta-right', =>
          @div class: 'btn-group', =>
            @button type: 'button', class: 'btn btn-info icon icon-cloud-download install-button', outlet: 'installButton', 'Install'
          @div outlet: 'buttons', class: 'btn-group', =>
            @button type: 'button', class: 'btn icon icon-gear',           outlet: 'settingsButton', 'Settings'
            @button type: 'button', class: 'btn icon icon-trashcan',       outlet: 'uninstallButton', 'Uninstall'
            @button type: 'button', class: 'btn icon icon-playback-pause', outlet: 'enablementButton', =>
              @span class: 'disable-text', 'Disable'
            @button type: 'button', class: 'btn btn-success status-indicator', tabindex: -1, outlet: 'statusIndicator'

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

    if atom.packages.isBundledPackage(@pack.name)
      @installButton.hide()
      @uninstallButton.hide()

    @installButton.on 'click', =>
      @install()

    @uninstallButton.on 'click', =>
      @uninstall()

    @settingsButton.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name, {back: opts?.back})

    @packageName.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name, {back: opts?.back})

    @enablementButton.on 'click', =>
      if atom.packages.isPackageDisabled(@pack.name)
        atom.packages.enablePackage(@pack.name)
      else
        atom.packages.disablePackage(@pack.name)
      @updateEnablement()
      false

  beforeRemove: ->
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
    @client.avatar @ownerFromRepository(@pack.repository), (err, path) =>
      @avatar.attr 'src', "file://#{path}"
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
        .addClass('btn-warning')
        .removeClass('btn-success')
    else
      @removeClass('disabled')
      @enablementButton.find('.disable-text').text('Disable')
      @enablementButton
        .addClass('icon-playback-pause')
        .removeClass('icon-playback-play')
      @statusIndicator
        .addClass('btn-success')
        .removeClass('btn-warning')

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
