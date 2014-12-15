path = require 'path'

fs = require 'fs-plus'
fuzzaldrin = require 'fuzzaldrin'
_ = require 'underscore-plus'
{$$, CompositeDisposable, View} = require 'atom'
{TextEditorView} = require 'atom-space-pen-views'

AvailablePackageView = require './available-package-view'
ErrorView = require './error-view'
PackageManager = require './package-manager'

module.exports =
class ThemesPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-container', =>
          @div class: 'section-heading icon icon-device-desktop', 'Choose a Theme'

          @div class: 'text native-key-bindings', tabindex: -1, =>
            @span class: 'icon icon-question', 'You can also style Atom by editing '
            @a class: 'link', outlet: 'openUserStysheet', 'your stylesheet'

          @form class: 'form-horizontal theme-chooser', =>
            @div class: 'form-group', =>
              @label class: 'col-sm-4 control-label themes-label text', 'UI Theme'
              @div class: 'col-sm-8', =>
                @select outlet: 'uiMenu', class: 'form-control'
                @div class: 'text theme-description', 'This styles the tabs, status bar, tree view, and dropdowns'

            @div class: 'form-group', =>
              @label class: 'col-sm-4 control-label themes-label text', 'Syntax Theme'
              @div class: 'col-sm-8', =>
                @select outlet: 'syntaxMenu', class: 'form-control'
                @div class: 'text theme-description', 'This styles the text inside the editor'

      @section class: 'section', =>
        @div class: 'section-container', =>
          @div class: 'section-heading icon icon-paintcan', =>
            @text 'Installed Themes'
            @span outlet: 'totalPackages', class:'section-heading-count', ' (…)'
          @div class: 'editor-container', =>
            @subview 'filterEditor', new TextEditorView(mini: true, placeholderText: 'Filter themes by name')

          @section class: 'sub-section installed-packages', =>
            @h3 class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Community Themes'
              @span outlet: 'communityCount', class:'section-heading-count', ' (…)'
            @div outlet: 'communityPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

          @section class: 'sub-section core-packages', =>
            @h3 class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Core Themes'
              @span outlet: 'coreCount', class:'section-heading-count', ' (…)'
            @div outlet: 'corePackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"

          @section class: 'sub-section dev-packages', =>
            @h3 class: 'sub-section-heading icon icon-paintcan', =>
              @text 'Development Themes'
              @span outlet: 'devCount', class:'section-heading-count', ' (…)'
            @div outlet: 'devPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading themes…"


  initialize: (@packageManager) ->
    @disposables = new CompositeDisposable()
    @packageViews = []
    @loadPackages()

    @subscribe @packageManager, 'theme-install-failed', (pack, error) =>
      @searchErrors.append(new ErrorView(@packageManager, error))

    @openUserStysheet.on 'click', =>
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'application:open-your-stylesheet')
      false

    @subscribe @packageManager, 'theme-installed', =>
      @populateThemeMenus()

    @disposables.add atom.themes.onDidReloadAll => @updateActiveThemes()
    @updateActiveThemes()

    @filterEditor.getModel().onDidStopChanging => @matchPackages()

    @syntaxMenu.change =>
      @activeSyntaxTheme = @syntaxMenu.val()
      @scheduleUpdateThemeConfig()

    @uiMenu.change =>
      @activeUiTheme = @uiMenu.val()
      @scheduleUpdateThemeConfig()

  beforeRemove: ->
    @disposables.dispose()

  filterThemes: (packages) ->
    packages.dev = packages.dev.filter ({theme}) -> theme
    packages.user = packages.user.filter ({theme}) -> theme
    packages.core = packages.core.filter ({theme}) -> theme

    packages

  loadPackages: ->
    @packageViews = []
    @packageManager.getInstalled()
      .then (packages) =>
        @packages = @filterThemes(packages)
        # @loadingMessage.hide()
        # TODO show empty mesage per section
        # @emptyMessage.show() if packages.length is 0
        @totalPackages.text " (#{@packages.user.length + @packages.core.length + @packages.dev.length})"

        _.each @addPackageViews(@communityPackages, @packages.user), (v) => @packageViews.push(v)
        @communityCount.text " (#{@packages.user.length})"

        @packages.core = @packages.core.map (p) ->
          # Assume core packages are in the atom org
          p.repository = "https://github.com/atom/#{p.name}" unless p.repository
          p

        _.each @addPackageViews(@corePackages, @packages.core), (v) => @packageViews.push(v)
        @coreCount.text " (#{@packages.core.length})"

        _.each @addPackageViews(@devPackages, @packages.dev), (v) => @packageViews.push(v)
        @devCount.text " (#{@packages.dev.length})"

      .catch (error) =>
        @loadingMessage.hide()
        @featuredErrors.append(new ErrorView(@packageManager, error))

  # Update the active UI and syntax themes and populate the menu
  updateActiveThemes: ->
    @activeUiTheme = @getActiveUiTheme()
    @activeSyntaxTheme = @getActiveSyntaxTheme()
    @populateThemeMenus()

  # Populate the theme menus from the theme manager's active themes
  populateThemeMenus: ->
    @uiMenu.empty()
    @syntaxMenu.empty()
    availableThemes = _.sortBy(atom.themes.getLoadedThemes(), 'name')
    for {name, metadata} in availableThemes
      switch metadata.theme
        when 'ui'
          themeItem = @createThemeMenuItem(name)
          themeItem.prop('selected', true) if name is @activeUiTheme
          @uiMenu.append(themeItem)
        when 'syntax'
          themeItem = @createThemeMenuItem(name)
          themeItem.prop('selected', true) if name is @activeSyntaxTheme
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
    atom.themes.setEnabledThemes(themes) if themes.length > 0

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

  addPackageViews: (container, packages) ->
    container.empty()
    packageViews = []

    packages.sort (left, right) ->
      leftStatus = atom.packages.isPackageDisabled(left.name)
      rightStatus = atom.packages.isPackageDisabled(right.name)
      if leftStatus == rightStatus
        return 0
      else if leftStatus > rightStatus
        return 1
      else
        return -1

    for pack, index in packages
      packageRow = $$ -> @div class: 'row'
      container.append(packageRow)
      packView = new AvailablePackageView(pack, @packageManager, {back: 'Themes'})
      packageViews.push(packView) # used for search filterin'
      packageRow.append(packView)

    packageViews

  filterPackageListByText: (text) ->
    return unless @packages
    active = fuzzaldrin.filter(@packageViews, text, key: 'filterText')

    _.each @packageViews, (view) ->
      # should set an attribute on the view we can filter by it instead of doing
      # dumb jquery stuff
      view.hide().addClass('hidden')
    _.each active, (view) ->
      view.show().removeClass('hidden')

    @totalPackages.text " (#{active.length}/#{@packageViews.length})"
    @updateSectionCounts()

  updateSectionCounts: ->
    filterText = @filterEditor.getEditor().getText()
    if filterText is ''
      @totalPackages.text " (#{@packages.user.length + @packages.core.length + @packages.dev.length})"
      @communityCount.text " (#{@packages.user.length})"
      @coreCount.text " (#{@packages.core.length})"
      @devCount.text " (#{@packages.dev.length})"
    else
      community = @communityPackages.find('.available-package-view:not(.hidden)').length
      @communityCount.text " (#{community}/#{@packages.user.length})"
      dev = @devPackages.find('.available-package-view:not(.hidden)').length
      @devCount.text " (#{dev}/#{@packages.dev.length})"
      core = @corePackages.find('.available-package-view:not(.hidden)').length
      @coreCount.text " (#{core}/#{@packages.core.length})"

  matchPackages: ->
    filterText = @filterEditor.getEditor().getText()
    @filterPackageListByText(filterText)
