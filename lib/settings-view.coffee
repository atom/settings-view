{$$} = require 'space-pen'
ScrollView = require 'scroll-view'
$ = require 'jquery'
_ = require 'underscore'
telepath = require 'telepath'

Pane = require 'pane'
GeneralPanel = require './general-panel'
ThemePanel = require './theme-panel'
PackagePanel = require './package-panel'
Project = require 'project'

###
# Internal #
###

module.exports =
class SettingsView extends ScrollView
  @content: ->
    @div id: 'settings-view', tabindex: -1, =>
      @div id: 'config-menu', =>
        @ul id: 'panels-menu', class: 'nav nav-pills nav-stacked', outlet: 'panelMenu'
        @button "Open ~/.atom", id: 'open-dot-atom', class: 'btn btn-default btn-small'
      @div id: 'panels', outlet: 'panels'

  initialize: (@state) ->
    super

    if @state
      activePanelName = @state.get('activePanelName')
      @uri = @state.get('uri')

    @panelsByName = {}
    @on 'click', '#panels-menu li a', (e) =>
      @showPanel($(e.target).closest('li').attr('name'))

    @on 'click', '#open-dot-atom', ->
      atom.open(pathsToOpen: [config.configDirPath])

    @addPanel('General', new GeneralPanel)
    @addPanel('Themes', new ThemePanel)
    @addPanel('Packages', new PackagePanel)
    @showPanel(activePanelName) if activePanelName

  serialize: -> @state.clone()

  getState: -> @state

  addPanel: (name, panel) ->
    panelItem = $$ -> @li name: name, => @a name
    @panelMenu.append(panelItem)
    panel.hide()
    @panelsByName[name] = panel
    @panels.append(panel)
    @showPanel(name) if @getPanelCount() is 1 or @panelToShow is name

  getPanelCount: ->
    _.values(@panelsByName).length

  getActivePanelName: -> @state.get('activePanelName')

  showPanel: (name) ->
    if @panelsByName[name]
      @panels.children().hide()
      @panelMenu.children('.active').removeClass('active')
      @panelsByName[name].show()
      for editorElement in @panelsByName[name].find(".editor")
        $(editorElement).view().redraw()
      @panelMenu.children("[name='#{name}']").addClass('active')
      @state.set('activePanelName', name)
      @panelToShow = null
    else
      @panelToShow = name

  getTitle: ->
    "Settings"

  getUri: ->
    @uri

  isEqual: (other) ->
    other instanceof SettingsView
