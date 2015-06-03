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
      'settings-view:view-packages': -> atom.workspace.open("#{configUri}/packages")
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

    unless localStorage.getItem('hasSeenDeprecatedNotification')
      packageManager.getInstalled().then (packages) =>
        @showDeprecatedNotification(packages)
      .catch (error) ->
        console.log error.message, error.stack

  showDeprecatedNotification: (packages) ->
    deprecatedPackages = packages.user.filter ({name, version}) ->
      atom.packages.isDeprecatedPackage(name, version)
    return unless deprecatedPackages.length

    were = 'were'
    have = 'have'
    packageText = 'packages'
    if packages.length is 1
      packageText = 'package'
      were = 'was'
      have = 'has'
    notification = atom.notifications.addWarning "#{deprecatedPackages.length} #{packageText} #{have} deprecations and #{were} not loaded.",
      description: 'This message will show only one time. Deprecated packages can be viewed in the settings view.'
      detail: (pack.name for pack in deprecatedPackages).join(', ')
      dismissable: true
      buttons: [{
        text: 'View Deprecated Packages',
        onDidClick: ->
          atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:view-packages')
          notification.dismiss()
      }]
    localStorage.setItem('hasSeenDeprecatedNotification', true)
