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
    atom.workspace.registerOpener (uri) ->
      createSettingsView({uri}) if uri is configUri

    atom.workspaceView.command 'settings-view:open', ->
      openPanel('Settings')

    atom.workspaceView.command 'settings-view:show-keybindings', ->
      openPanel('Keybindings')

    atom.workspaceView.command 'settings-view:change-themes', ->
      openPanel('Themes')

    atom.workspaceView.command 'settings-view:install-themes', ->
      openPanel('Themes')

    atom.workspaceView.command 'settings-view:install-packages', ->
      openPanel('Packages')

    atom.workspaceView.command 'settings-view:uninstall-themes', ->
      atom.workspaceView.open(configUri)

    atom.workspaceView.command 'settings-view:uninstall-packages', ->
      atom.workspaceView.open(configUri)

    atom.workspaceView.on 'pane-container:active-pane-item-changed', ->
      if settingsView is atom.workspace.getActivePaneItem()
        settingsView?.redrawEditors()

    atom.packages.once('activated', checkForUpdates)

checkForUpdates = ->
  if atom.workspaceView?.statusBar?
    PackageManager = require './package-manager'
    packageManager = new PackageManager()
    packageManager.getOutdated().then (packages) ->
      if packages.length > 0
        PackageUpdatesStatusView = require './package-updates-status-view'
        packageUpdatesStatusView = new PackageUpdatesStatusView(atom.workspaceView.statusBar, packages)
