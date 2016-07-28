{ScrollView} = require 'atom-space-pen-views'
SettingsPanel = require './settings-panel'

module.exports =
class EditorPanel extends ScrollView
  @content: ->
    @div tabindex: 0, class: 'panels-item', =>
      @form class: 'general-panel section', =>
        @div outlet: "loadingElement", class: 'alert alert-info loading-area icon icon-hourglass', "Loading settings"

  initialize: ->
    super
    @loadingElement.remove()

    @subPanels = [
      new SettingsPanel('editor', icon: 'code', note: '''
        <div class="text icon icon-question" id="editor-settings-note" tabindex="-1">These settings are related to text editing. Some of these can be overriden on a per-language basis. Check language settings by clicking its package card in the <a class="link packages-open">Packages list</a>.</div>
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
