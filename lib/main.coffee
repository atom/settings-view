_ = require 'underscore-plus'
[PackageManager, packageManager, SettingsView, settingsView] = []

SnippetsProvider =
  getSnippets: -> atom.config.scopedSettingsStore.propertySets

configUri = 'atom://config'
uriRegex = /config\/([a-z]+)\/?([a-zA-Z0-9_-]+)?/i

openPanel = (settingsView, panelName, uri) ->
  match = uriRegex.exec(uri)

  panel = match?[1]
  detail = match?[2]
  options = uri: uri
  if panel is "packages" and detail?
    panelName = detail
    options.pack = name: detail
    options.back = 'Packages' if atom.packages.getLoadedPackage(detail)

  settingsView.showPanel(panelName, options)

module.exports =
  activate: ->
    atom.workspace.addOpener (uri) =>
      if uri.startsWith(configUri)
        settingsView ?= @createSettingsView({uri})
        if match = uriRegex.exec(uri)
          panelName = match[1]
          panelName = panelName[0].toUpperCase() + panelName.slice(1)
          openPanel(settingsView, panelName, uri)
        settingsView

    atom.commands.add 'atom-workspace',
      'settings-view:open': -> atom.workspace.open(configUri)
      'settings-view:core': -> atom.workspace.open("#{configUri}/core")
      'settings-view:editor': -> atom.workspace.open("#{configUri}/editor")
      'settings-view:show-keybindings': -> atom.workspace.open("#{configUri}/keybindings")
      'settings-view:change-themes': -> atom.workspace.open("#{configUri}/themes")
      'settings-view:install-packages-and-themes': -> atom.workspace.open("#{configUri}/install")
      'settings-view:view-installed-themes': -> atom.workspace.open("#{configUri}/themes")
      'settings-view:uninstall-themes': -> atom.workspace.open("#{configUri}/themes")
      'settings-view:view-installed-packages': -> atom.workspace.open("#{configUri}/packages")
      'settings-view:uninstall-packages': -> atom.workspace.open("#{configUri}/packages")
      'settings-view:check-for-package-updates': -> atom.workspace.open("#{configUri}/updates")

    if process.platform is 'win32' and require('atom').WinShell?
      atom.commands.add 'atom-workspace', 'settings-view:system': -> atom.workspace.open("#{configUri}/system")

  deactivate: ->
    settingsView?.dispose()
    settingsView?.remove()
    settingsView = null
    packageManager = null

  consumeStatusBar: (statusBar) ->
    PackageManager ?= require './package-manager'
    packageManager ?= new PackageManager()

    Promise.resolve()
    .then =>
      Promise.all([
        packageManager.getJSONListResult("outdated"),
        packageManager.getJSONListResult('installed:packages')
        packageManager.getJSONListResult('installed:themes')
      ]).then (values) ->
        Promise.all([
          packageManager.storeList('outdated', values[0]),
          packageManager.storeList('installed:packages', values[1]),
          packageManager.storeList('installed:themes', values[2])
        ])
      .then (values) =>
        outdatedPackages = values[0]
        allPackages = _.flatten [_.values(values[1]), _.values(values[2])]

        if outdatedPackages.length > 0
          PackageUpdatesStatusView = require './package-updates-status-view'
          outdatedPackagesList = packageManager.cachedList('outdated', outdatedPackages)
          packageUpdatesStatusView = new PackageUpdatesStatusView(statusBar, outdatedPackagesList)
          packageManager.reloadCachedLists()
          packageManager.emit('updates-available')

        if allPackages.length > 0 and not localStorage.getItem('hasSeenDeprecatedNotification')
          @showDeprecatedNotification(allPackages)

  consumeSnippets: (snippets) ->
    if typeof snippets.getUnparsedSnippets is "function"
      SnippetsProvider.getSnippets = snippets.getUnparsedSnippets.bind(snippets)

  createSettingsView: (params) ->
    SettingsView ?= require './settings-view'
    PackageManager ?= require './package-manager'
    packageManager ?= new PackageManager()
    params.snippetsProvider = SnippetsProvider
    settingsView = new SettingsView(params, packageManager)

  showDeprecatedNotification: (packages) ->
    deprecatedPackages = packages.filter ({name, version}) ->
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

if parseFloat(atom.getVersion()) < 1.7
  atom.deserializers.add
    name: 'SettingsView'
    deserialize: module.exports.createSettingsView.bind(module.exports)
