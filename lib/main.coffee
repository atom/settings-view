SettingsView = null
settingsView = null

SnippetsProvider =
  getSnippets: -> atom.config.scopedSettingsStore.propertySets

configUri = 'atom://config'
uriRegex = /config\/([a-z]+)\/?([a-zA-Z0-9_-]+)?/i

createSettingsView = (params) ->
  SettingsView ?= require './settings-view'
  params.snippetsProvider ?= SnippetsProvider
  settingsView = new SettingsView(params)

openPanel = (panelName, uri) ->
  settingsView ?= createSettingsView({uri: configUri})
  match = uriRegex.exec(uri)

  panel = match?[1]
  detail = match?[2]
  options = uri: uri
  if panel is "packages" and detail?
    panelName = detail
    options.pack = name: detail
    options.back = 'Packages' if atom.packages.getLoadedPackage(detail)

  settingsView.showPanel(panelName, options)

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
        if match = uriRegex.exec(uri)
          panelName = match[1]
          panelName = panelName[0].toUpperCase() + panelName.slice(1)
          openPanel(panelName, uri)
        settingsView

    atom.commands.add 'atom-workspace',
      'settings-view:open': -> atom.workspace.open(configUri)
      'settings-view:show-keybindings': -> atom.workspace.open("#{configUri}/keybindings")
      'settings-view:change-themes': -> atom.workspace.open("#{configUri}/themes")
      'settings-view:install-packages-and-themes': -> atom.workspace.open("#{configUri}/install")
      'settings-view:view-installed-themes': -> atom.workspace.open("#{configUri}/themes")
      'settings-view:uninstall-themes': -> atom.workspace.open("#{configUri}/themes")
      'settings-view:view-installed-packages': -> atom.workspace.open("#{configUri}/packages")
      'settings-view:uninstall-packages': -> atom.workspace.open("#{configUri}/packages")
      'settings-view:check-for-package-updates': -> atom.workspace.open("#{configUri}/updates")

  deactivate: ->
    settingsView?.dispose()
    settingsView?.remove()
    settingsView = null

  consumeStatusBar: (statusBar) ->
    PackageManager = require './package-manager'
    packageManager = new PackageManager()
    Promise.all([packageManager.getOutdated(), packageManager.getInstalled()]).then (values) ->
      outdatedPackages = values[0]
      allPackages = values[1]
      if outdatedPackages.length > 0
        PackageUpdatesStatusView = require './package-updates-status-view'
        packageUpdatesStatusView = new PackageUpdatesStatusView(statusBar, outdatedPackages)

      if allPackages.length > 0 and not localStorage.getItem('hasSeenDeprecatedNotification')
        @showDeprecatedNotification(allPackages)
    .catch (error) ->
      console.log error.message, error.stack

  consumeSnippets: (snippets) ->
    if typeof snippets.getUnparsedSnippets is "function"
      SnippetsProvider.getSnippets = snippets.getUnparsedSnippets.bind(snippets)

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
          atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:view-installed-packages')
          notification.dismiss()
      }]
    localStorage.setItem('hasSeenDeprecatedNotification', true)
