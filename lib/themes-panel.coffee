path = require 'path'

fs = require 'fs-plus'
_ = require 'underscore-plus'
{$$, View, TextEditorView} = require 'atom'

AvailablePackageView = require './available-package-view'
ErrorView = require './error-view'
PackageManager = require './package-manager'

module.exports =
class ThemesPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-heading icon icon-device-desktop', 'Choose a Theme'

        @div class: 'text padded native-key-bindings', tabindex: -1, =>
          @span class: 'icon icon-question', 'You can also style Atom by editing '
          @a class: 'link', outlet: 'openUserStysheet', 'your stylesheet'

        @form class: 'form-horizontal theme-chooser', =>
          @div class: 'form-group', =>
            @label class: 'col-sm-2 col-lg-2 control-label themes-label text', 'UI Theme'
            @div class: 'col-sm-10 col-lg-4 col-md-4', =>
              @select outlet: 'uiMenu', class: 'form-control'
              @div class: 'text theme-description', 'This styles the tabs, status bar, tree view, and dropdowns'

          @div class: 'form-group', =>
            @label class: 'col-sm-2 col-lg-2 control-label themes-label text', 'Syntax Theme'
            @div class: 'col-sm-10 col-lg-4 col-md-4', =>
              @select outlet: 'syntaxMenu', class: 'form-control'
              @div class: 'text theme-description', 'This styles the text inside the editor'

          @div class: 'form-group', =>
            @label class: 'col-sm-2 col-lg-2 control-label themes-label text', 'Base Color'
            @div class: 'col-sm-10 col-lg-4 col-md-4', =>
              @div class: 'theme-base-color theme-base-color-1 theme-base-color-selected'
              @div class: 'theme-base-color theme-base-color-2'
              @div class: 'theme-base-color theme-base-color-3'
              @div class: 'theme-base-color theme-base-color-4'
              @div class: 'theme-base-color theme-base-color-5'

          @div class: 'form-group', =>
            @label class: 'col-sm-2 col-lg-2 control-label themes-label text', 'Saturation'
            @div class: 'col-sm-10 col-lg-4 col-md-4', =>
              @div class: 'theme-saturation theme-saturation-1', 'data-saturation': '20%'
              @div class: 'theme-saturation theme-saturation-2', 'data-saturation': '10%'
              @div class: 'theme-saturation theme-saturation-3 theme-saturation-selected', 'data-saturation': '0%'
              @div class: 'theme-saturation theme-saturation-4', 'data-saturation': '-10%'
              @div class: 'theme-saturation theme-saturation-5', 'data-saturation': '-20%'

          @div class: 'form-group', =>
            @label class: 'col-sm-2 col-lg-2 control-label themes-label text', 'Contrast'
            @div class: 'col-sm-10 col-lg-4 col-md-4', =>
              @div class: 'theme-contrast theme-contrast-1', 'data-contrast': '20%', 'A'
              @div class: 'theme-contrast theme-contrast-2', 'data-contrast': '10%', 'A'
              @div class: 'theme-contrast theme-contrast-3 theme-contrast-selected', 'data-contrast': '0%', 'A'
              @div class: 'theme-contrast theme-contrast-4', 'data-contrast': '-10%', 'A'
              @div class: 'theme-contrast theme-contrast-5', 'data-contrast': '-20%', 'A'

      @div class: 'section packages', =>
        @div class: 'section-heading icon icon-cloud-download', 'Install Themes'

        @div class: 'text padded native-key-bindings', tabindex: -1, =>
          @span class: 'icon icon-question'
          @span 'Themes are published to  '
          @a class: 'link', outlet: "openAtomIo", "atom.io"
          @span " and are installed to #{path.join(fs.getHomeDirectory(), '.atom', 'packages')}"


        @div class: 'editor-container padded', =>
          @subview 'searchEditorView', new TextEditorView(mini: true)

        @div outlet: 'searchErrors'
        @div outlet: 'searchMessage', class: 'alert alert-info icon icon-search search-message'
        @div outlet: 'resultsContainer', class: 'container package-container'

      @div class: 'section packages', =>
        @div class: 'section-heading icon icon-star', 'Featured Themes'
        @div outlet: 'featuredErrors'
        @div outlet: 'loadingMessage', class: 'alert alert-info icon icon-hourglass featured-message', 'Loading featured themes\u2026'
        @div outlet: 'emptyMessage', class: 'alert alert-info icon icon-heart featured-message', 'You have every featured theme installed already!'
        @div outlet: 'featuredContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    @openAtomIo.on 'click', =>
      require('shell').openExternal('https://atom.io/themes')
      false

    @searchMessage.hide()
    @emptyMessage.hide()

    @searchEditorView.setPlaceholderText('Search themes')
    @searchEditorView.on 'core:confirm', =>
      if query = @searchEditorView.getText().trim()
        @search(query)

    @subscribe @packageManager, 'theme-install-failed', (pack, error) =>
      @searchErrors.append(new ErrorView(@packageManager, error))

    @openUserStysheet.on 'click', =>
      atom.workspaceView.trigger('application:open-your-stylesheet')
      false

    @subscribe @packageManager, 'theme-installed', =>
      @populateThemeMenus()

    @subscribe atom.themes, 'reloaded', => @updateActiveThemes()
    @updateActiveThemes()

    @syntaxMenu.change =>
      @activeSyntaxTheme = @syntaxMenu.val()
      @scheduleUpdateThemeConfig()

    @uiMenu.change =>
      @activeUiTheme = @uiMenu.val()
      @scheduleUpdateThemeConfig()

    @loadFeaturedThemes()

    @on 'click', '.theme-base-color', ({target}) =>
      @find('.theme-base-color-selected').removeClass('theme-base-color-selected')

      target.classList.add('theme-base-color-selected')

      baseColor = window.getComputedStyle(target)['background-color']
      atom.config.set('core.themeColor', baseColor)

    @on 'click', '.theme-contrast', ({target}) =>
      @find('.theme-contrast-selected').removeClass('theme-contrast-selected')

      target.classList.add('theme-contrast-selected')

      {contrast} = target.dataset
      atom.config.set('core.themeContrast', contrast)

    @on 'click', '.theme-saturation', ({target}) =>
      @find('.theme-saturation-selected').removeClass('theme-saturation-selected')

      target.classList.add('theme-saturation-selected')

      {saturation} = target.dataset
      atom.config.set('core.themeSaturation', saturation)

  focus: ->
    @searchEditorView.focus()

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

  addThemeViews: (container, themes) ->
    container.empty()

    for theme, index in themes
      if index % 3 is 0
        themeRow = $$ -> @div class: 'row'
        container.append(themeRow)
      themeRow.append(new AvailablePackageView(theme, @packageManager))

  filterThemes: (themes) ->
    themes.filter ({theme}) -> theme

  # Load and display the featured themes available to install.
  loadFeaturedThemes: ->
    @loadingMessage.show()
    @emptyMessage.hide()

    @packageManager.getFeatured()
      .then (themes) =>
        themes = @filterThemes(themes)
        if themes.length is 0
          @loadingMessage.hide()
          @emptyMessage.removeClass('icon-heart').addClass('icon-rocket')
          @emptyMessage.text('No featured themes, create and publish one!')
          @emptyMessage.show()
        else
          themes = @filterThemes(themes)
          @loadingMessage.hide()
          @addThemeViews(@featuredContainer, themes)
          @emptyMessage.show() if themes.length is 0
      .catch (error) =>
        @loadingMessage.hide()
        @featuredErrors.append(new ErrorView(@packageManager, error))

  search: (query) ->
    if @resultsContainer.children().length is 0
      @searchMessage.text("Searching for \u201C#{query}\u201D\u2026").show()

    @packageManager.search(query, {themes: true})
      .then (themes=[]) =>
        if themes.length is 0
          @searchMessage.text("No theme results for \u201C#{query}\u201D").show()
        else
          @searchMessage.hide()
        @addThemeViews(@resultsContainer, themes)
      .catch (error) =>
        @searchMessage.hide()
        @searchErrors.append(new ErrorView(@packageManager, error))
