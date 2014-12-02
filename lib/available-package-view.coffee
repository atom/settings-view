_ = require 'underscore-plus'
{View} = require 'atom'
shell = require 'shell'

module.exports =
class AvailablePackageView extends View
  @content: ({name, description, version, repository}) ->
    # stars, downloads
    # lol wat
    owner = AvailablePackageView.prototype.ownerFromRepository(repository)

    @div class: 'available-package-view col-lg-8', =>
      @div class: 'stats top-meta meta-right', =>
        @span class: "stats-item", =>
          @span class: 'icon icon-versions'
          @span class:'value', version

        @span class: 'stats-item', =>
          @span class: 'icon icon-cloud-download'
          # if downloads?
          #   count = if downloads is 1 then '1 download' else "#{downloads.toLocaleString()} downloads"
          #   @span outlet: 'downloadCount', class: 'value', count
        @span class: 'stats-item', =>
          @div class: 'star-box', =>
            @a outlet: 'starButton', class: 'star-button btn icon icon-star', =>
            @a outlet: 'starCount', class: 'star-count'

      @div class: 'body', =>
        @h4 class: 'card-name', =>
          @a outlet: 'packageName', name
        @span outlet: 'packageDescription', class: 'package-description', description

      @div class: 'meta', =>
        @a outlet: 'avatarLink', =>
          @img class: 'avatar', src: "https://github.com/#{owner}.png" # TODO replace with cached asset
        @a outlet: 'loginLink', class: 'author', href: "https://atom.io/users/#{owner}", owner
        @div class: 'meta-right', =>
          @div outlet: 'buttons', class: 'btn-group', =>
            #
            # @button outlet: 'issueButton', class: 'btn btn-default icon icon-bug', 'Report Issue'
            # @button outlet: 'readmeButton', class: 'btn btn-default icon icon-book', 'Open README'
            # @button outlet: 'changelogButton', class: 'btn btn-default icon icon-squirrel', 'Open CHANGELOG'
            # @button outlet: 'openButton', class: 'btn btn-default icon icon-link-external', 'Open in Atom'
            #
            @button type: 'button', class: 'btn',outlet: 'installButton', => # TODO hide in installedpackagesview
              @span class: 'icon icon-cloud-download'
              @text "Install"
            @button type: 'button', class: 'btn', outlet: 'uninstallButton', => # TODO hide in installedpackagesview
              @span class: 'icon icon-trashcan'
              @text "Uninstall"
            @button outlet: 'enablementButton', class: 'btn btn-default', =>
              @span class: 'icon icon-playback-pause'
              @span class: 'disable-text', 'Disable'

  initialize: (@pack, @packageManager) ->
    @type = if @pack.theme then 'theme' else 'package'

    owner = @ownerFromRepository(@pack.repository)
    @filterText = "#{@pack.name} #{owner}"
    @name = @pack.name

    @handlePackageEvents()
    @updateEnablement()

    if atom.packages.isBundledPackage(@pack.name)
      @installButton.hide()
      @uninstallButton.hide()

    @installButton.on 'click', =>
      @install()

    @uninstallButton.on 'click', =>
      @uninstall()

    @packageName.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name, {back: 'Installed Packages'})

    @enablementButton.on 'click', =>
      if atom.packages.isPackageDisabled(@pack.name)
        atom.packages.enablePackage(@pack.name)
      else
        atom.packages.disablePackage(@pack.name)
      @updateEnablement()
      false

  ownerFromRepository: (repository) ->
    loginRegex = /github\.com\/([\w-]+)\/.+/
    if typeof(repository) is "string"
      repo = repository
    else
      repo = repository.url
    repo.match(loginRegex)[1]

  updateEnablement: ->
    if atom.packages.isPackageDisabled(@pack.name)
      @addClass('disabled')
      @enablementButton.find('.disable-text').text('Enable')
      @enablementButton
        .find('.icon')
        .addClass('icon-playback-play')
        .removeClass('icon-playback-pause')
    else
      @removeClass('disabled')
      @enablementButton.find('.disable-text').text('Disable')
      @enablementButton
        .find('.icon')
        .addClass('icon-playback-pause')
        .removeClass('icon-playback-play')

  handlePackageEvents: ->
    @subscribeToPackageEvent 'package-installed package-install-failed theme-installed theme-install-failed', (pack, error) =>
      @installButton.prop('disabled', false)
      unless error?
        @installButton.hide()
        @uninstallButton.show()

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

    if @isInstalled() or @isDisabled()
      @installButton.hide()
      @uninstallButton.show()

  isInstalled: -> atom.packages.isPackageLoaded(@pack.name) and not atom.packages.isPackageDisabled(@pack.name)

  isDisabled: -> atom.packages.isPackageDisabled(@pack.name)

  subscribeToPackageEvent: (event, callback) ->
    @subscribe @packageManager, event, (pack, error) =>
      callback(pack, error) if pack.name is @pack.name

  install: ->
    @packageManager.emit('package-installing', @pack)
    @packageManager.install @pack, (error) =>
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
