{View} = require 'atom'
SettingsPanel = require './settings-panel'

module.exports =
class GeneralPanel extends View
  @content: ->
    @form class: 'general-panel', =>
      @div outlet: "loadingElement", class: 'alert alert-info loading-area icon icon-hourglass', "Loading settings"

  initialize: ->
    @loadingElement.remove()

    @append(new SettingsPanel('core'))
    @append(new SettingsPanel('editor'))
