SettingsView = null
settingsView = null

configUri = 'atom://config'

createSettingsView = (params) ->
  SettingsView ?= require './settings-view'
  settingsView = new SettingsView(params)

openPanel = (panelName) ->
  atom.workspace.open(configUri).then -> settingsView?.showPanel(panelName)

deserializer =
  name: 'SettingsView'
  version: 2
  deserialize: (state) ->
    createSettingsView(state) if state.constructor is Object
atom.deserializers.add(deserializer)

module.exports =
  activate: ->
    atom.workspace.addOpener (uri) ->
      if uri.startsWith(configUri)
        settingsView = createSettingsView({uri})
        if match = /config\/([a-z]+)/gi.exec(uri)
          panelName = match[1]
          panelName = panelName[0].toUpperCase() + panelName.slice(1)
          openPanel(panelName)
        settingsView

    atom.commands.add 'atom-workspace',
      'settings-view:open': -> openPanel('Settings')
      'settings-view:show-keybindings': -> openPanel('Keybindings')
      'settings-view:change-themes': -> openPanel('Themes')
      'settings-view:install-packages-and-themes': -> openPanel('Install')
      'settings-view:uninstall-themes': -> openPanel('Themes')
      'settings-view:uninstall-packages': -> openPanel('Packages')
      'settings-view:check-for-package-updates': -> openPanel('Updates')

  consumeStatusBar: (statusBar) ->
    PackageManager = require './package-manager'
    packageManager = new PackageManager()
    packageManager.getOutdated().then (packages) ->
      if packages.length > 0
        PackageUpdatesStatusView = require './package-updates-status-view'
        packageUpdatesStatusView = new PackageUpdatesStatusView(statusBar, packages)
