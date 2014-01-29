_ = require 'underscore-plus'
{View} = require 'atom'
shell = require 'shell'

module.exports =
class ThemeView extends View
  @content: ({name, description}) ->
    @div class: 'col-lg-3 theme-view', =>
      @div class: 'thumbnail text', =>
        @div class: 'caption', =>
          @h4 _.undasherize(_.uncamelcase(name))
          @p description
          @div class: 'btn-toolbar', =>
            @button outlet: 'installButton', class: 'btn btn-primary', 'Install'
            @button outlet: 'learnMoreButton', class: 'btn btn-default', 'Learn More'

  initialize: (@theme, @packageManager) ->
    @installButton.on 'click', =>
      @packageManager.install @theme, (error) ->
        console.error("Installing theme #{@theme.name} failed", error.stack ? error)

    @learnMoreButton.on 'click', =>
      shell.openExternal "https://www.atom.io/packages/#{@theme.name}"
