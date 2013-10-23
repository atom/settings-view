{_, Document} = require 'atom'

SettingsView = null
settingsViewInstance = null

configUri = 'atom://config'

createSettingsView = (state) ->
  SettingsView ?= require './settings-view'
  unless state instanceof Document
    state = _.extend({deserializer: deserializer.name, version: deserializer.version}, state)
    state = site.createDocument(state)
  settingsViewInstance = new SettingsView(state)

deserializer =
  acceptsDocuments: true
  name: 'SettingsView'
  version: 1
  deserialize: (state) -> createSettingsView(state)
registerDeserializer(deserializer)

showPanelWhenInitialized = (panelName) ->
  settingsViewInstance.waitTilInitialized ->
    setImmediate ->
      settingsViewInstance.showPanel(panelName)

module.exports =
  activate: ->
    project.registerOpener (filePath) ->
      createSettingsView({uri: configUri}) if filePath is configUri

    rootView.command 'settings-view:toggle', ->
      rootView.open(configUri)
      showPanelWhenInitialized('General')

    rootView.command 'settings-view:show-Keybindings', ->
      rootView.open(configUri)
      showPanelWhenInitialized('Keybindings')

    rootView.command 'settings-view:change-themes', ->
      rootView.open(configUri)
      showPanelWhenInitialized('Themes')

    rootView.command 'settings-view:install-packages', ->
      rootView.open(configUri)
      showPanelWhenInitialized('Packages')
