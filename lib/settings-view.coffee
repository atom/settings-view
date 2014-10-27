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
PackageMenuView = require './package-menu-view'
PackagesPanel = require './packages-panel'
ThemesPanel = require './themes-panel'

module.exports =
class SettingsView extends ScrollView
  @content: ->
    @div class: 'settings-view pane-item', tabindex: -1, =>
      @div class: 'config-menu', outlet: 'sidebar', =>
        @div class: 'atom-banner'
        @ul class: 'panels-menu nav nav-pills nav-stacked', outlet: 'panelMenu', =>
          @div class: 'panel-menu-separator', outlet: 'menuSeparator'
          @div class: 'editor-container settings-filter', =>
            @subview 'filterEditor', new TextEditorView(mini: true, placeholderText: 'Filter packages')
        @ul class: 'panels-packages nav nav-pills nav-stacked', outlet: 'panelPackages'
        @div class: 'button-area', =>
          @button class: 'btn btn-default icon icon-link-external', outlet: 'openDotAtom', 'Open ~/.atom'
      @div class: 'panels padded', outlet: 'panels'

  initialize: ({@uri, activePanelName}={}) ->
    super
    @packageManager = new PackageManager()
    @handlePackageEvents()

    @panelToShow = activePanelName
    @filterEditor.hide()
    process.nextTick => @activatePackages => @initializePanels()

  handlePackageEvents: ->
    @subscribe @packageManager, 'package-installed theme-installed', ({name}) =>
      if pack = atom.packages.getLoadedPackage(name)
        title = @packageManager.getPackageTitle(pack)
        @addPackagePanel(pack)

        # Move added package menu item to properly sorted location
        for panelMenuItem in @panelPackages.children()
          compare = title.localeCompare($(panelMenuItem).view().nameLabel.text())
          if compare > 0
            beforeElement = panelMenuItem
          else if compare is 0
            addedPackageElement = panelMenuItem

        if beforeElement? and addedPackageElement?
          $(addedPackageElement).insertAfter(beforeElement)
          @filterPackages()

    @subscribe @packageManager, 'package-uninstalled', ({name}) =>
      @removePanel(name)
      @showPanel('Packages') if name is @activePanelName

    @subscribe @packageManager, 'theme-uninstalled', ({name}) =>
      @removePanel(name)
      @showPanel('Themes') if name is @activePanelName

  initializePanels: ->
    return if @panels.size > 0
    @currentPanel = null

    @panelsByName = {}
    @on 'click', '.panels-menu li a, .panels-packages li a', (e) =>
      @currentPanel = $(e.target).closest('li')
      @showPanel(@currentPanel.attr('name'))

    @on 'keydown', (e) =>
      return if @currentPanel == null
      switch e.which
        when 38  # up arrow
          curr = @currentPanel.prev('li')
          curr = curr.prev('li') while curr.length && curr.isHidden()
          curr.find('a')?.click() if curr.length
        when 40  # down arrow
          curr = @currentPanel.next('li')
          curr = curr.next('li') while curr.length && curr.isHidden()
          curr.find('a')?.click() if curr.length

    @openDotAtom.on 'click', ->
      atom.open(pathsToOpen: [atom.getConfigDirPath()])

    @filterEditor.getEditor().on 'contents-modified', =>
      @filterPackages()

    @addCorePanel 'Settings', 'settings', -> new GeneralPanel
    @addCorePanel 'Keybindings', 'keyboard', -> new KeybindingsPanel
    @addCorePanel 'Packages', 'package', => new PackagesPanel(@packageManager)
    @addCorePanel 'Themes', 'paintcan', => new ThemesPanel(@packageManager)

    @addPackagePanel(pack) for pack in @getPackages()
    @showPanel(@panelToShow) if @panelToShow
    @showPanel('Settings') unless @activePanelName
    @filterEditor.show()
    @sidebar.width(@sidebar.width()) if @isOnDom()

  afterAttach: (onDom) ->
    if onDom and @filterEditor.isVisible() and @sidebar.width() > 0
      @sidebar.width(@sidebar.width())

  serialize: ->
    deserializer: 'SettingsView'
    version: 2
    activePanelName: @activePanelName ? @panelToShow
    uri: @uri

  getPackages: ->
    return @packages if @packages?

    @packages = atom.packages.getLoadedPackages()
    # Include disabled packages so they can be re-enabled from the UI
    for packageName in atom.config.get('core.disabledPackages') ? []
      packagePath = atom.packages.resolvePackagePath(packageName)
      continue unless packagePath

      if metadataPath = CSON.resolve(path.join(packagePath, 'package'))
        try
          metadata = CSON.readFileSync(metadataPath)
          name = metadata?.name ? packageName
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
    panelMenuItem = new PackageMenuView(pack, @packageManager)
    @panelPackages.append(panelMenuItem)
    @addPanel pack.name, panelMenuItem, =>
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

  showPanel: (name) ->
    if panel = @getOrCreatePanel(name)
      @panels.children().hide()
      @panels.append(panel) unless $.contains(@panels[0], panel[0])
      panel.show()
      panel.focus()
      @makePanelMenuActive(name)
      @activePanelName = name
      @panelToShow = null
    else
      @panelToShow = name

  filterPackages: ->
    filterText = @filterEditor.getEditor().getText()
    all = _.map @panelPackages.children(), (item) ->
      element: $(item)
      text: $(item).text()
    active = fuzzaldrin.filter(all, filterText, key: 'text')
    _.each all, ({element}) -> element.hide()
    _.each active, ({element}) -> element.show()

  removePanel: (name) ->
    if panel = @panelsByName?[name]
      panel.remove()
      delete @panelsByName[name]
    @panelPackages.find("li[name=\"#{name}\"]").remove()

  getTitle: ->
    "Settings"

  getIconName: ->
    "tools"

  getUri: ->
    @uri

  isEqual: (other) ->
    other instanceof SettingsView

  activatePackages: (finishedCallback) ->
    iterator = (pack, callback) ->
      try
        pack.activateConfig()
      catch error
        console.error "Error activating package config for \u201C#{pack.name}\u201D", error
      finally
        callback()

    async.each atom.packages.getLoadedPackages(), iterator, finishedCallback
