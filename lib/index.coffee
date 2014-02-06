SettingsView = null
settingsView = null

configUri = 'atom://config'

createSettingsView = (params) ->
  SettingsView ?= require './settings-view'
  settingsView = new SettingsView(params)

openPanel = (panelName) ->
  atom.workspaceView.open(configUri)
  settingsView.showPanel(panelName)

deserializer =
  name: 'SettingsView'
  version: 2
  deserialize: (state) ->
    createSettingsView(state) if state.constructor is Object
atom.deserializers.add(deserializer)

module.exports =
  activate: ->
    atom.project.registerOpener (uri) ->
      createSettingsView({uri}) if uri is configUri

    atom.workspaceView.command 'settings-view:open', ->
      openPanel('General')

    atom.workspaceView.command 'settings-view:show-keybindings', ->
      openPanel('Keybindings')

    atom.workspaceView.command 'settings-view:change-themes', ->
      openPanel('Themes')

    atom.workspaceView.command 'settings-view:install-themes', ->
      openPanel('Themes')

    atom.workspaceView.command 'settings-view:install-packages', ->
      openPanel('Packages')
