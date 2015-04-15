path = require 'path'
_ = require 'underscore-plus'
{$, $$, ScrollView, TextEditorView} = require 'atom-space-pen-views'
{Disposable} = require 'atom'
{Subscriber} = require 'emissary'
async = require 'async'
CSON = require 'season'
fuzzaldrin = require 'fuzzaldrin'

Client = require './atom-io-client'
GeneralPanel = require './general-panel'
PackageDetailView = require './package-detail-view'
KeybindingsPanel = require './keybindings-panel'
PackageManager = require './package-manager'
InstallPanel = require './install-panel'
ThemesPanel = require './themes-panel'
InstalledPackagesPanel = require './installed-packages-panel'
UpdatesPanel = require './updates-panel'

class PanelsScrollView extends ScrollView
  @content: ->
    # Set tabindex to 0 so it can receive focus to get keyboard events
    @div class: 'panels', tabindex: '0'

  initialize: ->
    super

module.exports =
class SettingsView extends ScrollView
  Subscriber.includeInto(this)

  @content: ->
    @div class: 'settings-view pane-item', tabindex: -1, =>
      @div class: 'config-menu', outlet: 'sidebar', =>
        @ul class: 'panels-menu nav nav-pills nav-stacked', outlet: 'panelMenu', =>
          @div class: 'panel-menu-separator', outlet: 'menuSeparator'
        @div class: 'button-area', =>
          @button class: 'btn btn-default icon icon-link-external', outlet: 'openDotAtom', 'Open Config Folder'
      @subview 'panels', new PanelsScrollView

  initialize: ({@uri, activePanelName}={}) ->
    super
    @packageManager = new PackageManager()
    @handlePackageEvents()

    @panelToShow = activePanelName
    process.nextTick => @initializePanels()

  detached: ->
    @unsubscribe()

  #TODO Remove both of these post 1.0
  onDidChangeTitle: -> new Disposable()
  onDidChangeModified: -> new Disposable()

  handlePackageEvents: ->
    @subscribe @packageManager, 'package-installed theme-installed', ({name}) =>
      if pack = atom.packages.getLoadedPackage(name)
        @addPackagePanel(pack)

  initializePanels: ->
    return if @panels.size > 0

    @panelsByName = {}
    @on 'click', '.panels-menu li a, .panels-packages li a', (e) =>
      @showPanel($(e.target).closest('li').attr('name'))

    @on 'focus', =>
      @focusActivePanel()

    @openDotAtom.on 'click', ->
      atom.open(pathsToOpen: [atom.getConfigDirPath()])

    @addCorePanel 'Settings', 'settings', -> new GeneralPanel
    @addCorePanel 'Keybindings', 'keyboard', -> new KeybindingsPanel
    @addCorePanel 'Packages', 'package', => new InstalledPackagesPanel(@packageManager)
    @addCorePanel 'Themes', 'paintcan', => new ThemesPanel(@packageManager)
    @addCorePanel 'Updates', 'cloud-download', => new UpdatesPanel(@packageManager)
    @addCorePanel 'Install', 'plus', => new InstallPanel(@packageManager)

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
      new PackageDetailView(pack, @packageManager)

  addPanel: (name, panelMenuItem, panelCreateCallback) ->
    @panelCreateCallbacks ?= {}
    @panelCreateCallbacks[name] = panelCreateCallback
    @showPanel(name) if @panelToShow is name

  getOrCreatePanel: (name, opts) ->
    panel = @panelsByName?[name]
    # These nested conditionals are not great but I feel like it's the most
    # expedient thing to do - I feel like the "right way" involves refactoring
    # this whole file.
    unless panel?
      callback = @panelCreateCallbacks?[name]

      if opts?.pack and not callback
        callback = =>
          # sigh
          opts.pack.metadata = opts.pack
          new PackageDetailView(opts.pack, @packageManager)

      if callback
        panel = callback()
        @panelsByName ?= {}
        @panelsByName[name] = panel
        delete @panelCreateCallbacks[name]

    panel

  makePanelMenuActive: (name) ->
    @sidebar.find('.active').removeClass('active')
    @sidebar.find("[name='#{name}']").addClass('active')

  focusActivePanel: ->
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
    if panel = @getOrCreatePanel(name, opts)
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

  getURI: ->
    @uri

  isEqual: (other) ->
    other instanceof SettingsView
