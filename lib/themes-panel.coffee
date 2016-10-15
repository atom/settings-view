path = require 'path'

fs = require 'fs-plus'
_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
{$$, TextEditorView} = require 'atom-space-pen-views'

CollapsibleSectionPanel = require './collapsible-section-panel'
Package = require './package'
PackageCard = require './package-card'
ErrorView = require './error-view'
PackageManager = require './package-manager'

List = require './list'
ListView = require './list-view'
{ownerFromRepository, packageComparatorAscending} = require './utils'

module.exports =
class ThemesPanel extends CollapsibleSectionPanel
  @content: ->
    @div class: 'panels-item', =>
      @div class: 'section packages themes-panel', =>
        @div class: 'section-container', =>
          @div class: 'section-heading icon icon-paintcan', 'Choose a Theme'

          @div class: 'text native-key-bindings', tabindex: -1, =>
            @span class: 'icon icon-question', 'You can also style Atom by editing '
            @a class: 'link', outlet: 'openUserStysheet', 'your stylesheet'

          @div class: 'themes-picker', =>
            @div class: 'themes-picker-item control-group', =>
              @div class: 'controls', =>
                @label class: 'control-label', =>
                  @div class: 'setting-title themes-label text', 'UI Theme'
                  @div class: 'setting-description text theme-description', 'This styles the tabs, status bar, tree view, and dropdowns'
                @div class: 'select-container', =>
                  @select outlet: 'uiMenu', class: 'form-control'
                  @button outlet: 'activeUiThemeSettings', class: 'btn icon icon-gear active-theme-settings'

            @div class: 'themes-picker-item control-group', =>
              @div class: 'controls', =>
                @label class: 'control-label', =>
                  @div class: 'setting-title themes-label text', 'Syntax Theme'
                  @div class: 'setting-description text theme-description', 'This styles the text inside the editor'
                @div class: 'select-container', =>
                  @select outlet: 'syntaxMenu', class: 'form-control'
                  @button outlet: 'activeSyntaxThemeSettings', class: 'btn icon icon-gear active-theme-settings'

      @section class: 'section', =>
        @div class: 'section-container', =>
          @div class: 'section-heading icon icon-paintcan', =>
            @text 'Installed Themes'
            @span outlet: 'totalPackages', class: 'section-heading-count badge badge-flexible', '…'
          @div class: 'editor-container', =>
            @subview 'filterEditor', new TextEditorView(mini: true, placeholderText: 'Filter themes by name')

          @div outlet: 'themeErrors'

          @section class: 'sub-section installed-packages', =>
            @h3 outlet: 'userPackagesHeader', class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Community Themes'
              @span outlet: 'userCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'userPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

          @section class: 'sub-section core-packages', =>
            @h3 outlet: 'corePackagesHeader', class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Core Themes'
              @span outlet: 'coreCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'corePackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

          @section class: 'sub-section dev-packages', =>
            @h3 outlet: 'devPackagesHeader', class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Development Themes'
              @span outlet: 'devCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'devPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

          @section class: 'sub-section git-packages', =>
            @h3 outlet: 'gitPackagesHeader', class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Git Themes'
              @span outlet: 'gitCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'gitPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

  initialize: (@packageManager) ->
    super
    @itemViews = {}
    @handleEvents()
    @loadPackages()

    @disposables = new CompositeDisposable()

    @openUserStysheet.on 'click', ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'application:open-your-stylesheet')
      false

    @disposables.add atom.themes.onDidChangeActiveThemes => @updateActiveThemes()
    @disposables.add atom.tooltips.add(@activeUiThemeSettings, {title: 'Settings'})
    @disposables.add atom.tooltips.add(@activeSyntaxThemeSettings, {title: 'Settings'})

    @updateActiveThemes()

    @filterEditor.getModel().onDidStopChanging => @matchPackages()

    @syntaxMenu.change =>
      @activeSyntaxTheme = new Package({name: @syntaxMenu.val()}, @packageManager)
      @scheduleUpdateThemeConfig()

    @uiMenu.change =>
      @activeUiTheme = new Package({name: @uiMenu.val()}, @packageManager)
      @scheduleUpdateThemeConfig()

  focus: ->
    @filterEditor.focus()

  dispose: ->
    @disposables.dispose()

  loadPackages: ->
    @packageManager.getPackageList('installed:themes')
      .then (packageLists) =>
        @packages = packageLists

        _.each packageLists, (packagesList, listName) =>
          if section = @["#{listName}Packages"]
            packagesList.sort(packageComparatorAscending)
            @itemViews[listName] = new ListView(packagesList, section, @createPackageCard)
            @itemViews[listName].emitter.on 'updated', =>
              @updateSectionCounts()
              @matchPackages()
              @populateThemeMenus()

            section.find('.alert.loading-area').remove()

      .then =>
        @updateSectionCounts()
        @matchPackages()
        @updateActiveThemes()
        @packageManager.reloadCachedLists()

      .catch (error) =>
        console.error error.message
        @themeErrors.append(new ErrorView(@packageManager, error))

  # Update the active UI and syntax themes and populate the menu
  updateActiveThemes: ->
    @activeUiTheme = @getActiveUiTheme()
    @activeSyntaxTheme = @getActiveSyntaxTheme()
    @populateThemeMenus()
    @toggleActiveThemeButtons()
    @handleActiveThemeButtonEvents()

  handleActiveThemeButtonEvents: ->
    @activeUiThemeSettings.on 'click', (event) =>
      event.stopPropagation()
      activeUiTheme = atom.themes.getActiveThemes().filter((theme) -> theme.metadata.theme is 'ui')[0]?.metadata
      if activeUiTheme?
        @parents('.settings-view').view()?.showPanel(@activeUiTheme, {
          back: 'Themes',
          pack: activeUiTheme
        })

    @activeSyntaxThemeSettings.on 'click', (event) =>
      event.stopPropagation()
      activeSyntaxTheme = atom.themes.getActiveThemes().filter((theme) -> theme.metadata.theme is 'syntax')[0]?.metadata
      if activeSyntaxTheme?
        @parents('.settings-view').view()?.showPanel(@activeSyntaxTheme, {
          back: 'Themes',
          pack: activeSyntaxTheme
        })

  toggleActiveThemeButtons: ->
    if @activeUiTheme.hasSettings()
      @activeUiThemeSettings.show()
    else
      @activeUiThemeSettings.hide()

    if @activeSyntaxTheme.hasSettings()
      @activeSyntaxThemeSettings.show()
    else
      @activeSyntaxThemeSettings.hide()

  # Populate the theme menus from the theme manager's active themes
  populateThemeMenus: ->
    @uiMenu.empty()
    @syntaxMenu.empty()
    availableThemes = _.sortBy(atom.themes.getLoadedThemes(), 'name')
    for {name, metadata} in availableThemes
      switch metadata.theme
        when 'ui'
          themeItem = @createThemeMenuItem(name)
          themeItem.attr('selected', true) if name is @activeUiTheme.name
          @uiMenu.append(themeItem)
        when 'syntax'
          themeItem = @createThemeMenuItem(name)
          themeItem.attr('selected', true) if name is @activeSyntaxTheme.name
          @syntaxMenu.append(themeItem)

  # Get the name of the active ui theme.
  getActiveUiTheme: ->
    pkg = null
    for pack in atom.themes.getActiveThemes()
      if pack.metadata.theme is 'ui'
        pkg = new Package(pack, @packageManager)
    pkg if pkg

  # Get the name of the active syntax theme.
  getActiveSyntaxTheme: ->
    pkg = null
    for pack in atom.themes.getActiveThemes()
      if pack.metadata.theme is 'syntax'
        pkg = new Package(pack, @packageManager)
    pkg if pkg

  # Update the config with the selected themes
  updateThemeConfig: ->
    themes = []
    themes.push(@activeUiTheme.name) if @activeUiTheme
    themes.push(@activeSyntaxTheme.name) if @activeSyntaxTheme
    atom.config.set("core.themes", themes) if themes.length > 0

  scheduleUpdateThemeConfig: ->
    setTimeout((=> @updateThemeConfig()), 100)

  # Create a menu item for the given theme name.
  createThemeMenuItem: (themeName) ->
    title = @getThemeTitle(themeName)
    $$ -> @option value: themeName, title

  # Get a human readable title for the given theme name.
  getThemeTitle: (themeName='') ->
    title = themeName.replace(/-(ui|syntax)/g, '').replace(/-theme$/g, '')
    _.undasherize(_.uncamelcase(title))

  createPackageCard: (pack) ->
    packageRow = $$ -> @div class: 'row'
    packView = new PackageCard(pack, {back: 'Themes'})
    packageRow.append(packView)
    packageRow
