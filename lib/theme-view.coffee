_ = require 'underscore-plus'
{View} = require 'atom'

module.exports =
class ThemeView extends View
  @content: ({name, description}) ->
    @div class: 'col-lg-3 theme-view', =>
      @div class: 'thumbnail text', =>
        @div class: 'caption', =>
          @h3 _.undasherize(_.uncamelcase(name))
          @p description
          @button class: 'btn btn-primary', 'Install'

  initialize: (@theme) ->
