SettingsView = null
settingsView = null

configUri = 'atom://config'

createSettingsView = (params) ->
  SettingsView ?= require './settings-view'
  settingsView = new SettingsView(params)

openPanel = (panelName, uri) ->
  settingsView ?= createSettingsView({uri: configUri})
  settingsView.showPanel(panelName, {uri})

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
        settingsView ?= createSettingsView({uri})
        if match = /config\/([a-z]+)/gi.exec(uri)
          panelName = match[1]
          panelName = panelName[0].toUpperCase() + panelName.slice(1)
          openPanel(panelName, uri)
        settingsView

    atom.commands.add 'atom-workspace',
      'settings-view:open': -> atom.workspace.open(configUri)
      'settings-view:show-keybindings': -> atom.workspace.open("#{configUri}/keybindings")
      'settings-view:change-themes': -> atom.workspace.open("#{configUri}/themes")
      'settings-view:install-packages-and-themes': -> atom.workspace.open("#{configUri}/install")
      'settings-view:uninstall-themes': -> atom.workspace.open("#{configUri}/themes")
      'settings-view:uninstall-packages': -> atom.workspace.open("#{configUri}/packages")
      'settings-view:check-for-package-updates': -> atom.workspace.open("#{configUri}/updates")

  deactivate: ->
    settingsView?.remove()
    settingsView = null

  consumeStatusBar: (statusBar) ->
    PackageManager = require './package-manager'
    packageManager = new PackageManager()
    packageManager.getOutdated().then (packages) ->
      if packages.length > 0
        PackageUpdatesStatusView = require './package-updates-status-view'
        packageUpdatesStatusView = new PackageUpdatesStatusView(statusBar, packages)

        itemText = 'them'
        packageText = 'packages'
        if packages.length is 1
          itemText = 'it'
          packageText = 'package'
        notification = atom.notifications.addInfo "You have #{packages.length} outdated #{packageText}. Please upgrade #{itemText}.",
          description: 'Keeping packages up to date helps keep things speedy and breakage to a minimum. Upgrade often!'
          detail: (pack.name for pack in packages).join(', ')
          dismissable: true
          buttons: [{
            text: 'View and Upgrade Outdated Packages',
            onDidClick: ->
              atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:check-for-package-updates')
              notification.dismiss()
          }]
