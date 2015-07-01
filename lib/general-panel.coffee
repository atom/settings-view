{View} = require 'atom-space-pen-views'
SettingsPanel = require './settings-panel'

module.exports =
class GeneralPanel extends View
  @content: ->
    @div =>
      @form class: 'general-panel section', =>
        @div outlet: "loadingElement", class: 'alert alert-info loading-area icon icon-hourglass', "Loading settings"

  initialize: ->
    @loadingElement.remove()

    @subPanels = [
      new SettingsPanel('core')
      new SettingsPanel('editor')
    ]

    for subPanel in @subPanels
      @append(subPanel)
    return

  dispose: ->
    for subPanel in @subPanels
      subPanel.dispose()
    return
