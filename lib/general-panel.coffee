{ScrollView} = require 'atom-space-pen-views'
SettingsPanel = require './settings-panel'

module.exports =
class GeneralPanel extends ScrollView
  @content: ->
    @div tabindex: 0, class: 'panels-item', =>
      @form class: 'general-panel section', =>
        @div outlet: "loadingElement", class: 'alert alert-info loading-area icon icon-hourglass', "Loading settings"

  initialize: ->
    super
    @loadingElement.remove()

    @subPanels = [
      new SettingsPanel('core', icon: 'settings', note: '''
        <div class="text icon icon-question" id="core-settings-note" tabindex="-1">These are Atom's core settings which affect behavior unrelated to text editing. Individual packages may have their own additional settings found within their package card in the <a class="link packages-open">Packages list</a>.</div>
      ''')
    ]

    for subPanel in @subPanels
      @append(subPanel)

    @on 'click', '.packages-open', ->
      atom.workspace.open('atom://config/packages')

    return

  dispose: ->
    for subPanel in @subPanels
      subPanel.dispose()
    return
