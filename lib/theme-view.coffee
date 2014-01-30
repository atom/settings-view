_ = require 'underscore-plus'
{View} = require 'atom'
shell = require 'shell'

module.exports =
class ThemeView extends View
  @content: ({name, description}) ->
    @div class: 'col-lg-3 theme-view', =>
      @div class: 'thumbnail text', =>
        @div class: 'caption', =>
          @span outlet: 'status', class: 'theme-status icon'
          @h4 _.undasherize(_.uncamelcase(name))
          @p description
          @div class: 'btn-toolbar', =>
            @button outlet: 'installButton', class: 'btn btn-primary', 'Install'
            @button outlet: 'learnMoreButton', class: 'btn btn-default', 'Learn More'

  initialize: (@theme, @packageManager) ->
    @installButton.on 'click', =>
      @installButton.prop('disabled', true)
      @setStatusIcon('cloud-download')
      @packageManager.install @theme, (error) =>
        if error?
          @setStatusIcon('alert')
          @installButton.prop('disabled', false)
          console.error("Installing theme #{@theme.name} failed", error.stack ? error)
        else
          @setStatusIcon('check')

    @learnMoreButton.on 'click', =>
      shell.openExternal "https://www.atom.io/packages/#{@theme.name}"

  setStatusIcon: (iconName) ->
    @status.removeClass('icon-check icon-alert icon-cloud-download')
    @status.addClass("icon-#{iconName}")
    @status.destroyTooltip()
    switch iconName
      when 'check' then @status.setTooltip('Theme installed')
      when 'alert' then @status.setTooltip('Theme failed to install')
      when 'cloud-download' then @status.setTooltip('Theme installing')
