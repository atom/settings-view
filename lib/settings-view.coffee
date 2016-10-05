path = require 'path'
_ = require 'underscore-plus'
{$, $$, ScrollView, TextEditorView} = require 'atom-space-pen-views'
{Disposable} = require 'atom'
async = require 'async'
CSON = require 'season'
fuzzaldrin = require 'fuzzaldrin'

Client = require './atom-io-client'
GeneralPanel = require './general-panel'
EditorPanel = require './editor-panel'
PackageDetailView = require './package-detail-view'
KeybindingsPanel = require './keybindings-panel'
InstallPanel = require './install-panel'
ThemesPanel = require './themes-panel'
InstalledPackagesPanel = require './installed-packages-panel'
UpdatesPanel = require './updates-panel'
PackageManager = require './package-manager'

module.exports =
class SettingsView extends ScrollView

  @content: ->
    @div class: 'settings-view pane-item', tabindex: -1, =>
      @div class: 'config-menu', outlet: 'sidebar', =>
        @ul class: 'panels-menu nav nav-pills nav-stacked', outlet: 'panelMenu', =>
          @div class: 'panel-menu-separator', outlet: 'menuSeparator'
        @div class: 'button-area', =>
          @button class: 'btn btn-default icon icon-link-external', outlet: 'openDotAtom', 'Open Config Folder'
      # The tabindex attr below ensures that clicks in a panel item won't cause this view to gain focus.
      # This is important because when this view gains focus (e.g. immediately after atom displays it),
      # it focuses the currently active panel item. If that focusing causes the active panel to scroll (e.g.
      # because the active panel itself passes focus on to a search box at the top of a scrolled panel),
      # then the browser will not fire the click event on the element within the panel on which the user originally
      # clicked (e.g. a package card). This would prevent us from showing a package detail view when clicking on a
      # package card. Phew!
      @div class: 'panels', tabindex: -1, outlet: 'panels'

  initialize: ({@uri, @packageManager, @snippetsProvider, activePanel}={}) ->
    super

    @packageManager ?= new PackageManager()
    @deferredPanel = activePanel
    process.nextTick => @initializePanels()

  # This prevents the view being actually disposed when closed
  # If you remove it you will need to ensure the cached settingsView
  # in main.coffee is correctly released on close as well...
  onDidChangeTitle: -> new Disposable()

  dispose: ->
    for name, panel of @panelsByName
      panel.dispose?()
    return

  initializePanels: ->
    return if @panels.size() > 1

    @panelsByName = {}
    @on 'click', '.panels-menu li a, .panels-packages li a', (e) =>
      @showPanel($(e.target).closest('li').attr('name'))

    @on 'focus', =>
      @focusActivePanel()

    @openDotAtom.on 'click', ->
      atom.open(pathsToOpen: [atom.getConfigDirPath()])

    @addCorePanel 'Core', 'settings', -> new GeneralPanel
    @addCorePanel 'Editor', 'code', -> new EditorPanel
    if process.platform is 'win32' and require('atom').WinShell?
      SystemPanel = require './system-windows-panel'
      @addCorePanel 'System', 'device-desktop', -> new SystemPanel
    @addCorePanel 'Keybindings', 'keyboard', -> new KeybindingsPanel
    @addCorePanel 'Packages', 'package', => new InstalledPackagesPanel(@packageManager)
    @addCorePanel 'Themes', 'paintcan', => new ThemesPanel(@packageManager)
    @addCorePanel 'Updates', 'cloud-download', => new UpdatesPanel(@packageManager)
    @addCorePanel 'Install', 'plus', => new InstallPanel(@packageManager)

    @showDeferredPanel()
    @showPanel('Core') unless @activePanel
    @sidebar.width(@sidebar.width()) if @isOnDom()

  serialize: ->
    deserializer: 'SettingsView'
    version: 2
    activePanel: @activePanel ? @deferredPanel
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

  addPanel: (name, panelMenuItem, panelCreateCallback) ->
    @panelCreateCallbacks ?= {}
    @panelCreateCallbacks[name] = panelCreateCallback
    @showDeferredPanel() if @deferredPanel?.name is name

  getOrCreatePanel: (name, options) ->
    panel = @panelsByName?[name]
    # These nested conditionals are not great but I feel like it's the most
    # expedient thing to do - I feel like the "right way" involves refactoring
    # this whole file.
    unless panel?
      callback = @panelCreateCallbacks?[name]

      if options?.pack and not callback
        callback = =>
          unless options.pack.metadata
            metadata = _.clone(options.pack)
            options.pack.metadata = metadata
          new PackageDetailView(options.pack, @packageManager, @snippetsProvider)

      if callback
        panel = callback()
        @panelsByName ?= {}
        @panelsByName[name] = panel
        delete @panelCreateCallbacks?[name]

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

  showDeferredPanel: ->
    return unless @deferredPanel?
    {name, options} = @deferredPanel
    @showPanel(name, options)

  # Public: show a panel.
  #
  # * `name` {String} the name of the panel to show
  # * `options` {Object} an options hash. Will be passed to `beforeShow()` on
  #   the panel. Options may include (but are not limited to):
  #   * `uri` the URI the panel was launched from
  showPanel: (name, options) ->
    if panel = @getOrCreatePanel(name, options)
      @appendPanel(panel, options)
      @makePanelMenuActive(name)
      @setActivePanel(name, options)
      @deferredPanel = null
    else
      @deferredPanel = {name, options}

  appendPanel: (panel, options) ->
    @panels.children().hide()
    @panels.append(panel) unless $.contains(@panels[0], panel[0])
    panel.beforeShow?(options)
    panel.show()
    panel.focus()

  setActivePanel: (name, options = {}) ->
    @activePanel = {name, options}

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
