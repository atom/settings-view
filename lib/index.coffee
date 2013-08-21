Project = require 'project'

configUri = 'atom://config'
SettingsView = null

createSettingsView = (state) ->
  SettingsView ?= require './settings-view'
  new SettingsView(state)

registerDeserializer
  name: 'SettingsView'
  version: 1
  deserialize: (state) -> createSettingsView(state)

module.exports =
  activate: ->
    Project.registerOpener (filePath) ->
      createSettingsView({uri: configUri}) if filePath is configUri

    rootView.command 'settings-view:toggle', -> rootView.open(configUri)
