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
  atom.workspaceView.open(configUri)
  settingsView.showPanel(panelName)

deserializer =
  acceptsDocuments: true
  name: 'SettingsView'
  version: 1
  deserialize: (state) -> createSettingsView(state)
atom.deserializers.add(deserializer)

module.exports =
  activate: ->
    atom.project.registerOpener (uri) ->
      createSettingsView({uri: configUri}) if uri is configUri

    atom.workspaceView.command 'settings-view:toggle', ->
      openPanel('General')

    atom.workspaceView.command 'settings-view:show-keybindings', ->
      openPanel('Keybindings')

    atom.workspaceView.command 'settings-view:change-themes', ->
      openPanel('Themes')

    atom.workspaceView.command 'settings-view:install-packages', ->
      openPanel('Packages')
