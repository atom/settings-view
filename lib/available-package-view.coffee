_ = require 'underscore-plus'
{View} = require 'atom'
shell = require 'shell'

module.exports =
class AvailablePackageView extends View
  @content: ({name, description, version, repository}) ->
    loginRegex = /github\.com\/([\w-]+)\/.+/
    if typeof(repository) is "string"
      repo = repository
    else
      repo = repository.url
    owner = repo.match(loginRegex)[1]
    # stars, downloads

    @div class: 'available-package-view col-lg-4', =>
      @div class: 'body', =>
        @h4 class: 'card-name', =>
          @a outlet: 'packageName', name
        @span outlet: 'packageDescription', class: 'package-description', description, =>
      @div class: 'meta', =>
        @a outlet: 'avatarLink', =>
          @img class: 'avatar', src: "https://github.com/#{owner}.png" # TODO replace with cached asset
        @a outlet: 'loginLink', class: 'author', href: "https://atom.io/users/#{owner}", owner
        @div class: 'meta-right', =>
          @span class: "stat", =>
            @span class: 'icon icon-versions'
            @span class:'value', version

          @span class: 'stat', =>
            @span class: 'icon icon-cloud-download'
            # if downloads?
            #   count = if downloads is 1 then '1 download' else "#{downloads.toLocaleString()} downloads"
            #   @span outlet: 'downloadCount', class: 'value', count
          @span class: 'star-wrap', =>
            @div class: 'star-box', =>
              @a outlet: 'starButton', class: 'star-button', =>
                @span class: 'icon icon-star'
              @a outlet: 'starCount', class: 'star-count'
      @div class: 'meta-lower', =>
        @div outlet: 'buttons', class: 'btn-group', =>
          #
          # @button outlet: 'disableButton', class: 'btn btn-default icon'
          # @button outlet: 'uninstallButton', class: 'btn btn-default icon icon-trashcan', 'Uninstall'
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
          @button outlet: 'disableButton', class: 'btn btn-default icon'
          @button type: 'button', class: 'btn', outlet: 'learnMoreButton', =>
            @span class: 'icon icon-book'
            @text "Learn more"
          @button type: 'button', class: 'btn', outlet: 'settingsButton', =>
            @span class: 'icon icon-gear'
            @text "Settings"
        @span outlet: 'status', class: 'package-status icon'

  initialize: (@pack, @packageManager) ->
    @type = if @pack.theme then 'theme' else 'package'

    @handlePackageEvents()

    if atom.packages.isBundledPackage(@pack.name)
      @installButton.hide()
      @uninstallButton.hide()

    @installButton.on 'click', =>
      @install()

    @uninstallButton.on 'click', =>
      @uninstall()

    @packageName.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name)

    @settingsButton.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name)

    @learnMoreButton.on 'click', =>
      shell.openExternal "https://atom.io/packages/#{@pack.name}"

  handlePackageEvents: ->
    @subscribeToPackageEvent 'package-installed package-install-failed theme-installed theme-install-failed', (pack, error) =>
      @installButton.prop('disabled', false)
      if error?
        @setStatusIcon('alert')
      else
        @setStatusIcon('check')
        @settingsButton.show()
        @installButton.hide()
        @uninstallButton.show()

    @subscribeToPackageEvent 'package-installing', (pack) =>
      @installButton.prop('disabled', true)
      @installButton.show()
      @uninstallButton.hide()
      @setStatusIcon('cloud-download')

    @subscribeToPackageEvent 'package-uninstalling', (pack) =>
      @installButton.prop('disabled', true)
      @setStatusIcon()

    @subscribeToPackageEvent 'package-uninstalled package-uninstall-failed theme-uninstalled theme-uninstall-failed', (pack, error) =>
      @installButton.prop('disabled', false)
      if error?
        @setStatusIcon('alert')
      else
        @installButton.show()
        @uninstallButton.hide()
        @settingsButton.hide()
        @setStatusIcon()

    if @isInstalled()
      @installButton.hide()
      @uninstallButton.show()
      @setStatusIcon('check')
    else
      @settingsButton.hide()

  isInstalled: -> atom.packages.isPackageLoaded(@pack.name)

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

  setStatusIcon: (iconName) ->
    @status.removeClass('icon-check icon-alert icon-cloud-download')
    @status.addClass("icon-#{iconName}") if iconName
    @status.destroyTooltip()
    switch iconName
      when 'check'
        @status.setTooltip(_.capitalize("#{@type} installed"))
      when 'alert'
        @status.setTooltip(_.capitalize("#{@type} failed to install"))
      when 'cloud-download'
        @status.setTooltip(_.capitalize("#{@type} installing"))
