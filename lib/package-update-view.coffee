_ = require 'underscore-plus'
{View} = require 'atom'

module.exports =
class PackageUpdateView extends View
  @content: ({name, description}) ->
    @div class: 'col-lg-4 available-package-view', =>
      @div class: 'thumbnail text', =>
        @div class: 'caption', =>
          @span outlet: 'status', class: 'package-status icon'
          @h4 class: 'package-name native-key-bindings', tabindex: -1, _.undasherize(_.uncamelcase(name))
          @p outlet: 'latestVersion', class: 'description native-key-bindings', tabindex: -1
          @div class: 'btn-toolbar', =>
            @button outlet: 'upgradeButton', class: 'btn btn-primary', 'Update'
            @button outlet: 'uninstallButton', class: 'btn btn-default', 'Uninstall'
            @button outlet: 'settingsButton', class: 'btn btn-default', 'Settings'

  initialize: (@pack, @packageManager) ->
    @type = if @pack.theme then 'theme' else 'package'

    @latestVersion.text("Version #{@pack.latestVersion} is now available. #{@pack.version} is currently installed.")

    @handlePackageEvents()

    @upgradeButton.on 'click', =>
      @upgrade()

    @uninstallButton.on 'click', =>
      @uninstall()

    @settingsButton.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name)

  handlePackageEvents: ->
    @subscribeToPackageEvent 'package-updated theme-updated package-update-failed theme-update-failed', (pack, error) =>
      if error?
        @uninstallButton.prop('disabled', false)
        @setStatusIcon('alert')
      else
        @setStatusIcon('check')

    @subscribeToPackageEvent 'package-updating', (pack) =>
      @setButtonsEnabled(false)
      @setStatusIcon('cloud-download')

    @subscribeToPackageEvent 'package-uninstalling', (pack) =>
      @setButtonsEnabled(false)
      @setStatusIcon()

    @subscribeToPackageEvent 'package-uninstalled package-uninstall-failed theme-uninstalled theme-uninstall-failed', (pack, error) =>
      if error?
        @setButtonsEnabled(true)
        @setStatusIcon('alert')
      else
        @remove()

  setButtonsEnabled: (enabled) ->
    @upgradeButton.prop('disabled', not enabled)
    @uninstallButton.prop('disabled', not enabled)

  subscribeToPackageEvent: (event, callback) ->
    @subscribe @packageManager, event, (pack, error) =>
      callback(pack, error) if pack.name is @pack.name

  uninstall: ->
    @packageManager.emit('package-uninstalling', @pack)
    @packageManager.uninstall @pack, (error) =>
      if error?
        console.error("Uninstalling #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)

  upgrade: ->
    @packageManager.update @pack, @pack.latestVersion, (error) =>
      if error?
        console.error("Upgrading #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)

  setStatusIcon: (iconName) ->
    @status.removeClass('icon-check icon-alert icon-cloud-download')
    @status.addClass("icon-#{iconName}") if iconName
    @status.destroyTooltip()
    switch iconName
      when 'check'
        @status.setTooltip(_.capitalize("#{@type} updated"))
      when 'alert'
        @status.setTooltip(_.capitalize("#{@type} failed to updated"))
      when 'cloud-download'
        @status.setTooltip(_.capitalize("#{@type} updating"))
