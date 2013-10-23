{_, Document} = require 'atom'

SettingsView = null
settingsView = null

configUri = 'atom://config'

createSettingsView = (state) ->
  SettingsView ?= require './settings-view'
  unless state instanceof Document
    state = _.extend({deserializer: deserializer.name, version: deserializer.version}, state)
    state = site.createDocument(state)
  settingsView = new SettingsView(state)

deserializer =
  acceptsDocuments: true
  name: 'SettingsView'
  version: 1
  deserialize: (state) -> createSettingsView(state)
registerDeserializer(deserializer)

module.exports =
  activate: ->
    project.registerOpener (filePath) ->
      createSettingsView({uri: configUri}) if filePath is configUri

    rootView.command 'settings-view:toggle', ->
      rootView.open(configUri)
      settingsView.showPanel('General')

    rootView.command 'settings-view:show-keybindings', ->
      rootView.open(configUri)
      settingsView.showPanel('Keybindings')

    rootView.command 'settings-view:change-themes', ->
      rootView.open(configUri)
      settingsView.showPanel('Themes')

    rootView.command 'settings-view:install-packages', ->
      rootView.open(configUri)
      settingsView.showPanel('Packages')
