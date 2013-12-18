async = require 'async'
{_, $, $$, ScrollView} = require 'atom'

GeneralPanel = require './general-panel'
ThemePanel = require './theme-panel'
PackagePanel = require './package-panel'
KeybindingPanel = require './keybinding-panel'

###
# Internal #
###

module.exports =
class SettingsView extends ScrollView
  @content: ->
    @div class: 'settings-view pane-item', tabindex: -1, =>
      @div class: 'config-menu', =>
        @div class: 'atom-banner'
        @ul class: 'panels-menu nav nav-pills nav-stacked', outlet: 'panelMenu'
        @div class: 'padded', =>
          @button "Open ~/.atom", class: 'open-dot-atom btn btn-default btn-small'
      @div class: 'panels padded', outlet: 'panels'

  initialize: ({@uri, @activePanelName}={}) ->
    super
    @panelToShow = null
    process.nextTick => @activatePackages => @initializePanels()

  initializePanels: ->
    return if @panels.size > 0

    activePanelName = @panelToShow ? @activePanelName

    @panelsByName = {}
    @on 'click', '.panels-menu li a', (e) =>
      @showPanel($(e.target).closest('li').attr('name'))

    @on 'click', '.open-dot-atom', ->
      atom.open(pathsToOpen: [atom.getConfigDirPath()])

    @addPanel('General Settings', new GeneralPanel)
    @addPanel('Keybindings', new KeybindingPanel)
    @addPanel('Themes', new ThemePanel)
    @addPanel('Packages', new PackagePanel)

    @showPanel(activePanelName) if activePanelName

  serialize: ->
    deserializer: 'SettingsView'
    version: 2
    activePanelName: @activePanelName

  addPanel: (name, panel) ->
    panelItem = $$ -> @li name: name, => @a name
    @panelMenu.append(panelItem)
    panel.hide()
    @panelsByName[name] = panel
    @panels.append(panel)
    @showPanel(name) if @getPanelCount() is 1 or @panelToShow is name

  getPanelCount: ->
    _.values(@panelsByName).length

  showPanel: (name) ->
    if @panelsByName?[name]
      @panels.children().hide()
      @panelMenu.children('.active').removeClass('active')
      @panelsByName[name].show()
      for editorElement in @panelsByName[name].find(".editor")
        $(editorElement).view().redraw()
      @panelMenu.children("[name='#{name}']").addClass('active')
      @activePanelName = name
      @panelToShow = null
    else
      @panelToShow = name

  getTitle: ->
    "Settings"

  getUri: ->
    @uri

  isEqual: (other) ->
    other instanceof SettingsView

  activatePackages: (finishedCallback) ->
    iterator = (pack, callback) ->
      try
        pack.activateConfig()
      catch error
        console.error "Error activating package config for '#{pack.name}'", error
      finally
        callback()

    async.each atom.packages.getLoadedPackages(), iterator, finishedCallback
