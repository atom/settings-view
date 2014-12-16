SettingsView = null
settingsView = null

configUri = 'atom://config'

createSettingsView = (params) ->
  SettingsView ?= require './settings-view'
  settingsView = new SettingsView(params)

openPanel = (panelName) ->
  atom.workspace.open(configUri)
  settingsView.showPanel(panelName)

deserializer =
  name: 'SettingsView'
  version: 2
  deserialize: (state) ->
    createSettingsView(state) if state.constructor is Object
atom.deserializers.add(deserializer)

module.exports =
  activate: ->
    atom.workspace.addOpener (uri) ->
      createSettingsView({uri}) if uri is configUri

    atom.commands.add 'atom-workspace',
      'settings-view:open': -> openPanel('Settings')
      'settings-view:show-keybindings': -> openPanel('Keybindings')
      'settings-view:change-themes': -> openPanel('Themes')
      'settings-view:install-packages-and-themes': -> openPanel('Install')
      'settings-view:uninstall-themes': -> openPanel('Themes')
      'settings-view:uninstall-packages': -> openPanel('Packages')
      'settings-view:check-for-package-updates': -> openPanel('Updates')

    atom.packages.onDidActivateAll(checkForUpdates)

checkForUpdates = ->
  if statusBar = atom.views.getView(atom.workspace)?.querySelector('status-bar')
    PackageManager = require './package-manager'
    packageManager = new PackageManager()
    packageManager.getOutdated().then (packages) ->
      if packages.length > 0
        PackageUpdatesStatusView = require './package-updates-status-view'
        packageUpdatesStatusView = new PackageUpdatesStatusView(statusBar, packages)
