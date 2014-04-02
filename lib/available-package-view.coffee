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

  initialize: (@pack, @packageManager) ->
    @type = if @pack.theme then 'theme' else 'package'

    @handlePackageEvents()

    @installButton.on 'click', =>
      @packageManager.emit('package-installing', @pack)

      @packageManager.install @pack, (error) =>
        if error?
          console.error("Installing #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)

    @learnMoreButton.on 'click', =>
      shell.openExternal "https://atom.io/packages/#{@pack.name}"

  handlePackageEvents: ->
    @subscribe @packageManager, 'package-installed package-install-failed theme-installed theme-install-failed', (pack, error) =>
      if pack.name is @pack.name
        if error?
          @setStatusIcon('alert')
          @installButton.prop('disabled', false)
        else
          @setStatusIcon('check')
          @installButton.text('Installed')

    @subscribe @packageManager, 'package-installing', (pack) =>
      if pack.name is @pack.name
        @installButton.prop('disabled', true)
        @setStatusIcon('cloud-download')

    @subscribe @packageManager, 'package-uninstalled package-uninstall-failed theme-uninstalled theme-uninstall-failed', (pack, error) =>
      if pack.name is @pack.name
        if error?
          @setStatusIcon('alert')
        else
          @installButton.prop('disabled', false)
          @installButton.text('Install')
          @setStatusIcon()

    if atom.packages.isPackageLoaded(@pack.name)
      @installButton.prop('disabled', true)
      @installButton.text('Installed')
      @setStatusIcon('check')

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
