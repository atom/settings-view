_ = require 'underscore'
telepath = require 'telepath'

Project = require 'project'
SettingsView = null

configUri = 'atom://config'

createSettingsView = (state) ->
  SettingsView ?= require './settings-view'
  unless state instanceof telepath.Document
    state = _.extend({deserializer: deserializer.name, version: deserializer.version}, state)
    state = site.createDocument(state)
  new SettingsView(state)

deserializer =
  acceptsDocuments: true
  name: 'SettingsView'
  version: 1
  deserialize: (state) -> createSettingsView(state)
registerDeserializer(deserializer)

module.exports =
  activate: ->
    Project.registerOpener (filePath) ->
      createSettingsView({uri: configUri}) if filePath is configUri

    rootView.command 'settings-view:toggle', -> rootView.open(configUri)
