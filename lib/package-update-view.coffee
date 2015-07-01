_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'

module.exports =
class PackageUpdateView extends View

  @content: ({name, description}) ->
    @div class: 'col-md-6 package-update-view', =>
      @div outlet: 'thumbnail', class: 'thumbnail text', =>
        @div class: 'caption', =>
          @span outlet: 'status', class: 'package-status icon'
          @h4 class: 'package-name native-key-bindings', tabindex: -1, _.undasherize(_.uncamelcase(name))
          @p outlet: 'latestVersion', class: 'description native-key-bindings', tabindex: -1
          @div class: 'btn-toolbar', =>
            @button outlet: 'upgradeButton', class: 'btn btn-primary upgrade-button', 'Update'
            @button outlet: 'uninstallButton', class: 'btn btn-default', 'Uninstall'
            @button outlet: 'settingsButton', class: 'btn btn-default', 'Settings'

  initialize: (@pack, @packageManager) ->
    @type = if @pack.theme then 'theme' else 'package'

    @latestVersion.html("Version <span class='highlight'>#{@pack.latestVersion}</span> is now available. #{@pack.version} is currently installed.")

    @handlePackageEvents()

    @upgradeButton.on 'click', =>
      @upgrade()

    @uninstallButton.on 'click', =>
      @uninstall()

    @settingsButton.on 'click', =>
      @parents('.settings-view').view()?.showPanel(@pack.name, {back: 'Available Updates'})

  dispose: ->
    @statusTooltip?.dispose()
    @packageManagerSubscription.dispose()

  handlePackageEvents: ->
    @subscribeToPackageEvent 'package-updated theme-updated package-update-failed theme-update-failed', (pack, error) =>
      if error?
        @setButtonsEnabled(true)
        @setStatusIcon('alert')
        @setUpgradeButton()
      else
        @uninstallButton.prop('disabled', false)
        @latestVersion.text("Version #{@pack.latestVersion} is now installed.")
        @setStatusIcon('check')
        @setUpgradeButton('check')

    @subscribeToPackageEvent 'package-updating', (pack) =>
      @setButtonsEnabled(false)
      @setStatusIcon('cloud-download')
      @setUpgradeButton('cloud-download')

    @subscribeToPackageEvent 'package-uninstalling', (pack) =>
      @setButtonsEnabled(false)
      @setStatusIcon()
      @setUpgradeButton()

    @subscribeToPackageEvent 'package-uninstalled package-uninstall-failed theme-uninstalled theme-uninstall-failed', (pack, error) =>
      if error?
        @setButtonsEnabled(true)
        @setStatusIcon('alert')
        @setUpgradeButton()

  setButtonsEnabled: (enabled) ->
    @upgradeButton.prop('disabled', not enabled)
    @uninstallButton.prop('disabled', not enabled)

  subscribeToPackageEvent: (event, callback) ->
    @packageManagerSubscription = @packageManager.on event, (pack, error) =>
      callback(pack, error) if pack.name is @pack.name

  uninstall: ->
    @packageManager.uninstall @pack, (error) =>
      if error?
        console.error("Uninstalling #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)

  upgrade: ->
    return if @upgradeButton.prop('disabled')

    @packageManager.update @pack, @pack.latestVersion, (error) =>
      if error?
        console.error("Upgrading #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)

  setStatusIcon: (iconName) ->
    @status.removeClass('icon-check icon-alert icon-cloud-download')
    @status.addClass("icon-#{iconName}") if iconName
    @statusTooltip?.dispose()
    switch iconName
      when 'check'
        tooltip = _.capitalize("#{@type} updated")
      when 'alert'
        tooltip = _.capitalize("#{@type} failed to update")
      when 'cloud-download'
        tooltip = _.capitalize("#{@type} updating")

    if tooltip
      @statusTooltip = atom.tooltips.add(@status[0], title: tooltip)

  setUpgradeButton: (iconName) ->
    @upgradeButton.removeClass('btn-primary btn-progress btn-success icon icon-check icon-alert icon-cloud-download')
    @upgradeButton.addClass("icon icon-#{iconName}") if iconName
    switch iconName
      when undefined
        @upgradeButton.addClass('btn-primary')
        @upgradeButton.text('Update')
      when 'cloud-download'
        @upgradeButton.addClass('btn-progress')
        @upgradeButton.text('Updating...')
      when 'check'
        @upgradeButton.addClass('btn-success')
        @upgradeButton.text('Updated')
