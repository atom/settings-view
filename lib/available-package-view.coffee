_ = require 'underscore-plus'
{View} = require 'atom'
shell = require 'shell'

module.exports =
class AvailablePackageView extends View
  @content: ({name, description}) ->
    @div class: 'col-lg-3 available-package-view', =>
      @div class: 'thumbnail text', =>
        @div class: 'caption', =>
          @span outlet: 'status', class: 'package-status icon'
          @h4 class: 'package-name', _.undasherize(_.uncamelcase(name))
          @p class: 'description', description ? ''
          @div class: 'btn-toolbar', =>
            @button outlet: 'installButton', class: 'btn btn-primary', 'Install'
            @button outlet: 'learnMoreButton', class: 'btn btn-default', 'Learn More'

  initialize: (@pack, @packageManager) ->
    @type = if @pack.theme then 'theme' else 'package'

    @handlePackageEvents()

    @installButton.on 'click', =>
      @packageManager.emit('package-installing', @pack)

      @packageManager.install @pack, (error) =>
        if error
          console.error("Installing #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)

    @learnMoreButton.on 'click', =>
      shell.openExternal "https://atom.io/packages/#{@pack.name}"

  handlePackageEvents: ->
    @subscribe @packageManager, 'package-installed package-install-failed theme-installed', (pack, error) =>
      if pack.name == @pack.name
        if error
          @setStatusIcon('alert')
          @installButton.prop('disabled', false)
        else
          @setStatusIcon('check')
          @installButton.text('Installed')

    @subscribe @packageManager, 'package-installing', (pack) =>
      if pack.name == @pack.name
        @installButton.prop('disabled', true)
        @setStatusIcon('cloud-download')

  setStatusIcon: (iconName) ->
    @status.removeClass('icon-check icon-alert icon-cloud-download')
    @status.addClass("icon-#{iconName}")
    @status.destroyTooltip()
    switch iconName
      when 'check'
        @status.setTooltip(_.capitalize("#{@type} installed"))
      when 'alert'
        @status.setTooltip(_.capitalize("#{@type} failed to install"))
      when 'cloud-download'
        @status.setTooltip(_.capitalize("#{@type} installing"))
