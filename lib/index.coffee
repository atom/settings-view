{_, Document} = require 'atom'

SettingsView = null
settingsView = null

configUri = 'atom://config'

createSettingsView = (state) ->
  SettingsView ?= require './settings-view'
  unless state instanceof Document
    state = _.extend({deserializer: deserializer.name, version: deserializer.version}, state)
    state = atom.site.createDocument(state)
  settingsView = new SettingsView(state)

openPanel = (panelName) ->
  atom.rootView.open(configUri)
  settingsView.showPanel(panelName)

deserializer =
  acceptsDocuments: true
  name: 'SettingsView'
  version: 1
  deserialize: (state) -> createSettingsView(state)
atom.deserializers.add(deserializer)

module.exports =
  activate: ->
    project.registerOpener (filePath) ->
      createSettingsView({uri: configUri}) if filePath is configUri

    rootView.command 'settings-view:toggle', ->
      openPanel('General')

    rootView.command 'settings-view:show-keybindings', ->
      openPanel('Keybindings')

    rootView.command 'settings-view:change-themes', ->
      openPane('Themes')

    rootView.command 'settings-view:install-packages', ->
      openPanel('Packages')
