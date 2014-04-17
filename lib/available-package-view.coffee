_ = require 'underscore-plus'
{View} = require 'atom'
shell = require 'shell'

module.exports =
class AvailablePackageView extends View
  @content: ({name, description, downloads}) ->
    @div class: 'col-lg-4 available-package-view', =>
      @div class: 'thumbnail text', =>
        @div class: 'caption', =>
          @span outlet: 'status', class: 'package-status icon'
          @h4 class: 'package-name native-key-bindings', tabindex: -1, _.undasherize(_.uncamelcase(name))
          if downloads >= 0
            @p class: 'downloads native-key-bindings', tabindex: -1, _.pluralize(downloads, 'download')
          @p class: 'description native-key-bindings', tabindex: -1, description ? ''
          @div class: 'btn-toolbar', =>
            @button outlet: 'installButton', class: 'btn btn-primary', 'Install'
            @button outlet: 'learnMoreButton', class: 'btn btn-default', 'Learn More'
            @button outlet: 'settingsButton', class: 'btn btn-default', 'Settings'

  initialize: (@pack, @packageManager) ->
    @type = if @pack.theme then 'theme' else 'package'

    @handlePackageEvents()

    @installButton.on 'click', =>
      if @isInstalled()
        @uninstall()
      else
        @install()

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
        @installButton.text('Uninstall')

    @subscribeToPackageEvent 'package-installing', (pack) =>
      @installButton.prop('disabled', true)
      @installButton.text('Install')
      @setStatusIcon('cloud-download')

    @subscribeToPackageEvent 'package-uninstalling', (pack) =>
      @installButton.prop('disabled', true)
      @setStatusIcon()

    @subscribeToPackageEvent 'package-uninstalled package-uninstall-failed theme-uninstalled theme-uninstall-failed', (pack, error) =>
      @installButton.prop('disabled', false)
      if error?
        @setStatusIcon('alert')
      else
        @installButton.text('Install')
        @settingsButton.hide()
        @setStatusIcon()

    if @isInstalled()
      @installButton.text('Uninstall')
      @setStatusIcon('check')
    else
      @settingsButton.hide()
      @installButton.prop('disabled', true) if @isDisabled()

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
