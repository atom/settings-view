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
      new SettingsPanel('core', note: '''
        <div class="alert alert-info" id="core-settings-note">These are Atom's core settings which affect behavior unrelated to text editing. Individual packages might have additional config settings of their own. Check individual package settings by selecting the package in the <a class="packages-open">Packages list</a>.</div>
      ''')

      new SettingsPanel('editor', note: '''
        <div class="alert alert-info" id="editor-settings-note">These config settings are related to text editing. Some of these settings can be overriden on a per-language basis. Check language package settings by selecting the package for a specific language in the <a class="packages-open">Packages list</a>.</div>
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
