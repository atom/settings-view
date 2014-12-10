path = require 'path'
_ = require 'underscore-plus'
{$, $$, ScrollView, TextEditorView} = require 'atom'
async = require 'async'
CSON = require 'season'
fuzzaldrin = require 'fuzzaldrin'

GeneralPanel = require './general-panel'
InstalledPackageView = require './installed-package-view'
KeybindingsPanel = require './keybindings-panel'
PackageManager = require './package-manager'
InstallPanel = require './packages-panel'
ThemesPanel = require './themes-panel'
InstalledPackagesPanel = require './installed-packages-panel.coffee'
UpdatesPanel = require './updates-panel.coffee'

module.exports =
class SettingsView extends ScrollView
  @content: ->
    @div class: 'settings-view pane-item', tabindex: -1, =>
      @div class: 'config-menu', outlet: 'sidebar', =>
        @ul class: 'panels-menu nav nav-pills nav-stacked', outlet: 'panelMenu', =>
          @div class: 'panel-menu-separator', outlet: 'menuSeparator'
        @div class: 'button-area', =>
          @button class: 'btn btn-default icon icon-link-external', outlet: 'openDotAtom', 'Open ~/.atom'
      @div class: 'panels', outlet: 'panels'

  initialize: ({@uri, activePanelName}={}) ->
    super
    @packageManager = new PackageManager()
    @handlePackageEvents()

    @panelToShow = activePanelName
    process.nextTick => @initializePanels()

  handlePackageEvents: ->
    @subscribe @packageManager, 'package-installed theme-installed', ({name}) =>
      if pack = atom.packages.getLoadedPackage(name)
        @addPackagePanel(pack)

    @subscribe @packageManager, 'package-uninstalled', ({name}) =>
      @removePanel(name)
      @showPanel('Packages') if name is @activePanelName

    @subscribe @packageManager, 'theme-uninstalled', ({name}) =>
      @removePanel(name)
      @showPanel('Themes') if name is @activePanelName

  initializePanels: ->
    return if @panels.size > 0

    @panelsByName = {}
    @on 'click', '.panels-menu li a, .panels-packages li a', (e) =>
      @showPanel($(e.target).closest('li').attr('name'))

    @openDotAtom.on 'click', ->
      atom.open(pathsToOpen: [atom.getConfigDirPath()])

    @addCorePanel 'Settings', 'settings', -> new GeneralPanel
    @addCorePanel 'Keybindings', 'keyboard', -> new KeybindingsPanel
    @addCorePanel 'Packages', 'package', => new InstalledPackagesPanel(@packageManager)
    @addCorePanel 'Themes', 'paintcan', => new ThemesPanel(@packageManager)
    @addCorePanel 'Install', 'cloud-download', => new InstallPanel(@packageManager)
    @addCorePanel 'Updates', 'squirrel', => new UpdatesPanel(@packageManager)

    @addPackagePanel(pack) for pack in @getPackages()
    @showPanel(@panelToShow) if @panelToShow
    @showPanel('Settings') unless @activePanelName
    @sidebar.width(@sidebar.width()) if @isOnDom()

  serialize: ->
    deserializer: 'SettingsView'
    version: 2
    activePanelName: @activePanelName ? @panelToShow
    uri: @uri

  getPackages: ->
    return @packages if @packages?

    @packages = atom.packages.getLoadedPackages()

    try
      bundledPackageMetadataCache = require(path.join(atom.getLoadSettings().resourcePath, 'package.json'))?._atomPackages

    # Include disabled packages so they can be re-enabled from the UI
    for packageName in atom.config.get('core.disabledPackages') ? []
      packagePath = atom.packages.resolvePackagePath(packageName)
      continue unless packagePath

      try
        metadata = require(path.join(packagePath, 'package.json'))
      catch error
        metadata = bundledPackageMetadataCache?[packageName]?.metadata
      continue unless metadata?

      name = metadata.name ? packageName
      unless _.findWhere(@packages, {name})
        @packages.push({name, metadata, path: packagePath})

    @packages.sort (pack1, pack2) =>
      title1 = @packageManager.getPackageTitle(pack1)
      title2 = @packageManager.getPackageTitle(pack2)
      title1.localeCompare(title2)

    @packages

  addCorePanel: (name, iconName, panel) ->
    panelMenuItem = $$ ->
      @li name: name, =>
        @a class: "icon icon-#{iconName}", name
    @menuSeparator.before(panelMenuItem)
    @addPanel(name, panelMenuItem, panel)

  addPackagePanel: (pack) ->
    @addPanel pack.name, null, =>
      new InstalledPackageView(pack, @packageManager)

  addPanel: (name, panelMenuItem, panelCreateCallback) ->
    @panelCreateCallbacks ?= {}
    @panelCreateCallbacks[name] = panelCreateCallback
    @showPanel(name) if @panelToShow is name

  getOrCreatePanel: (name) ->
    panel = @panelsByName?[name]
    unless panel?
      if callback = @panelCreateCallbacks?[name]
        panel = callback()
        @panelsByName ?= {}
        @panelsByName[name] = panel
        delete @panelCreateCallbacks[name]
    panel

  makePanelMenuActive: (name) ->
    @sidebar.find('.active').removeClass('active')
    @sidebar.find("[name='#{name}']").addClass('active')

  focus: ->
    super

    # Pass focus to panel that is currently visible
    for panel in @panels.children()
      child = $(panel)
      if child.isVisible()
        if view = child.view()
          view.focus()
        else
          child.focus()
        return

  showPanel: (name, opts) ->
    if panel = @getOrCreatePanel(name)
      @panels.children().hide()
      @panels.append(panel) unless $.contains(@panels[0], panel[0])
      panel.beforeShow?(opts)
      panel.show()
      panel.focus()
      @makePanelMenuActive(name)
      @activePanelName = name
      @panelToShow = null
    else
      @panelToShow = name

  removePanel: (name) ->
    if panel = @panelsByName?[name]
      panel.remove()
      delete @panelsByName[name]

  getTitle: ->
    "Settings"

  getIconName: ->
    "tools"

  getUri: ->
    @uri

  isEqual: (other) ->
    other instanceof SettingsView
