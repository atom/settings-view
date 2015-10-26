path = require 'path'

fs = require 'fs-plus'
fuzzaldrin = require 'fuzzaldrin'
_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
{$$, TextEditorView} = require 'atom-space-pen-views'

CollapsibleSectionPanel = require './collapsible-section-panel'
PackageCard = require './package-card'
ErrorView = require './error-view'
PackageManager = require './package-manager'

List = require './list'
ListView = require './list-view'
{ownerFromRepository, packageComparatorAscending} = require './utils'

module.exports =
class ThemesPanel extends CollapsibleSectionPanel
  @loadPackagesDelay: 300

  @content: ->
    @div class: 'panels-item', =>
      @div class: 'section packages themes-panel', =>
        @div class: 'section-container', =>
          @div class: 'section-heading icon icon-device-desktop', 'Choose a Theme'

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
            @h3 outlet: 'communityThemesHeader', class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Community Themes'
              @span outlet: 'communityCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'communityPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

          @section class: 'sub-section core-packages', =>
            @h3 outlet: 'coreThemesHeader', class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Core Themes'
              @span outlet: 'coreCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'corePackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

          @section class: 'sub-section dev-packages', =>
            @h3 outlet: 'developmentThemesHeader', class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Development Themes'
              @span outlet: 'devCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'devPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

  initialize: (@packageManager) ->
    super
    @items =
      dev: new List('name')
      core: new List('name')
      user: new List('name')
    @itemViews =
      dev: new ListView(@items.dev, @devPackages, @createPackageCard)
      core: new ListView(@items.core, @corePackages, @createPackageCard)
      user: new ListView(@items.user, @communityPackages, @createPackageCard)

    @handleEvents()
    @loadPackages()

    @disposables = new CompositeDisposable()
    @disposables.add @packageManager.on 'theme-install-failed theme-uninstall-failed', ({pack, error}) =>
      @themeErrors.append(new ErrorView(@packageManager, error))

    @openUserStysheet.on 'click', ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'application:open-your-stylesheet')
      false

    @disposables.add @packageManager.on 'theme-installed theme-uninstalled', =>
      clearTimeout(loadPackagesTimeout)
      loadPackagesTimeout = setTimeout =>
        @populateThemeMenus()
        @loadPackages()
      , ThemesPanel.loadPackagesDelay

    @disposables.add atom.themes.onDidChangeActiveThemes => @updateActiveThemes()
    @disposables.add atom.tooltips.add(@activeUiThemeSettings, {title: 'Settings'})
    @disposables.add atom.tooltips.add(@activeSyntaxThemeSettings, {title: 'Settings'})
    @updateActiveThemes()

    @filterEditor.getModel().onDidStopChanging => @matchPackages()

    @syntaxMenu.change =>
      @activeSyntaxTheme = @syntaxMenu.val()
      @scheduleUpdateThemeConfig()

    @uiMenu.change =>
      @activeUiTheme = @uiMenu.val()
      @scheduleUpdateThemeConfig()

  focus: ->
    @filterEditor.focus()

  dispose: ->
    @disposables.dispose()

  filterThemes: (packages) ->
    packages.dev = packages.dev.filter ({theme}) -> theme
    packages.user = packages.user.filter ({theme}) -> theme
    packages.core = packages.core.filter ({theme}) -> theme

    for pack in packages.core
      pack.repository ?= "https://github.com/atom/#{pack.name}"

    for packageType in ['dev', 'core', 'user']
      for pack in packages[packageType]
        pack.owner = ownerFromRepository(pack.repository)
    packages

  sortThemes: (packages) ->
    packages.dev.sort(packageComparatorAscending)
    packages.core.sort(packageComparatorAscending)
    packages.user.sort(packageComparatorAscending)
    packages

  loadPackages: ->
    @packageViews = []
    @packageManager.getInstalled()
      .then (packages) =>
        @packages = @sortThemes(@filterThemes(packages))

        @devPackages.find('.alert.loading-area').remove()
        @items.dev.setItems(@packages.dev)

        @corePackages.find('.alert.loading-area').remove()
        @items.core.setItems(@packages.core)

        @communityPackages.find('.alert.loading-area').remove()
        @items.user.setItems(@packages.user)

        # TODO show empty mesage per section

        @updateSectionCounts()

      .catch (error) =>
        @loadingMessage.hide()
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
    if @hasSettings(@activeUiTheme)
      @activeUiThemeSettings.show()
    else
      @activeUiThemeSettings.hide()

    if @hasSettings(@activeSyntaxTheme)
      @activeSyntaxThemeSettings.show()
    else
      @activeSyntaxThemeSettings.hide()

  hasSettings: (packageName) -> @packageManager.packageHasSettings(packageName)

  # Populate the theme menus from the theme manager's active themes
  populateThemeMenus: ->
    @uiMenu.empty()
    @syntaxMenu.empty()
    availableThemes = _.sortBy(atom.themes.getLoadedThemes(), 'name')
    for {name, metadata} in availableThemes
      switch metadata.theme
        when 'ui'
          themeItem = @createThemeMenuItem(name)
          themeItem.attr('selected', true) if name is @activeUiTheme
          @uiMenu.append(themeItem)
        when 'syntax'
          themeItem = @createThemeMenuItem(name)
          themeItem.attr('selected', true) if name is @activeSyntaxTheme
          @syntaxMenu.append(themeItem)

  # Get the name of the active ui theme.
  getActiveUiTheme: ->
    for {name, metadata} in atom.themes.getActiveThemes()
      return name if metadata.theme is 'ui'
    null

  # Get the name of the active syntax theme.
  getActiveSyntaxTheme: ->
    for {name, metadata} in atom.themes.getActiveThemes()
      return name if metadata.theme is 'syntax'
    null

  # Update the config with the selected themes
  updateThemeConfig: ->
    themes = []
    themes.push(@activeUiTheme) if @activeUiTheme
    themes.push(@activeSyntaxTheme) if @activeSyntaxTheme
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

  createPackageCard: (pack) =>
    packageRow = $$ -> @div class: 'row'
    packView = new PackageCard(pack, @packageManager, {back: 'Themes'})
    packageRow.append(packView)
    packageRow

  filterPackageListByText: (text) ->
    return unless @packages

    for packageType in ['dev', 'core', 'user']
      allViews = @itemViews[packageType].getViews()
      activeViews = @itemViews[packageType].filterViews (pack) ->
        return true if text is ''
        owner = pack.owner ? ownerFromRepository(pack.repository)
        filterText = "#{pack.name} #{owner}"
        fuzzaldrin.score(filterText, text) > 0

      for view in allViews when view
        view.find('.package-card').hide().addClass('hidden')
      for view in activeViews when view
        view.find('.package-card').show().removeClass('hidden')

    @updateSectionCounts()

  updateUnfilteredSectionCounts: ->
    @updateSectionCount(@communityThemesHeader, @communityCount, @packages.user.length)
    @updateSectionCount(@coreThemesHeader, @coreCount, @packages.core.length)
    @updateSectionCount(@developmentThemesHeader, @devCount, @packages.dev.length)

    @totalPackages.text "#{@packages.user.length + @packages.core.length + @packages.dev.length}"

  updateFilteredSectionCounts: ->
    community = @notHiddenCardsLength(@communityPackages)
    @updateSectionCount(@communityThemesHeader, @communityCount, community, @packages.user.length)

    dev = @notHiddenCardsLength(@devPackages)
    @updateSectionCount(@developmentThemesHeader, @devCount, dev, @packages.dev.length)

    core = @notHiddenCardsLength(@corePackages)
    @updateSectionCount(@coreThemesHeader, @coreCount, core, @packages.core.length)

  resetSectionHasItems: ->
    @resetCollapsibleSections([@communityThemesHeader, @coreThemesHeader, @developmentThemesHeader])

  matchPackages: ->
    filterText = @filterEditor.getModel().getText()
    @filterPackageListByText(filterText)
