_ = require 'underscore-plus'
{$$, View} = require 'atom'

PackageManager = require './package-manager'
AvailablePackageView = require './available-package-view'

module.exports =
class ThemesPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-heading theme-heading icon icon-device-desktop', 'Choose a Theme'

        @div class: 'text padded', =>
          @span class: 'icon icon-question', 'You can also style Atom by editing '
          @a class: 'link', outlet: 'openUserStysheet', 'your stylesheet'

        @form class: 'form-horizontal theme-chooser', =>
          @div class: 'form-group', =>
            @label class: 'control-label themes-label text', 'UI Theme'
            @div class: 'col-lg-4', =>
              @select outlet: 'uiMenu', class: 'form-control'
              @div class: 'text theme-description', 'This styles the tabs, status bar, tree view, and dropdowns'

          @div class: 'form-group', =>
            @label class: 'control-label themes-label text', 'Syntax Theme'
            @div class: 'col-lg-4', =>
              @select outlet: 'syntaxMenu', class: 'form-control'
              @div class: 'text theme-description', 'This styles the text inside the editor'

      @div class: 'section packages', =>
        @div class: 'section-heading theme-heading icon icon-cloud-download', 'Install Themes'
        @div outlet: 'loadingMessage', class: 'padded text icon icon-hourglass', 'Loading themes\u2026'
        @div outlet: 'emptyMessage', class: 'padded text icon icon-heart', 'You have every theme installed already!'
        @div outlet: 'themeContainer', class: 'container package-container', =>
          @div outlet: 'themeRow', class: 'row'

  initialize: (@packageManager) ->
    @openUserStysheet.on 'click', =>
      atom.workspaceView.trigger('application:open-your-stylesheet')
      false

    @subscribe @packageManager, 'theme-installed', =>
      @populateThemeMenus()

    @observeConfig 'core.themes', =>
      @activeUiTheme = @getActiveUiTheme()
      @activeSyntaxTheme = @getActiveSyntaxTheme()
      @populateThemeMenus()

    @syntaxMenu.change =>
      @activeSyntaxTheme = @syntaxMenu.val()
      @updateThemeConfig()

    @uiMenu.change =>
      @activeUiTheme = @uiMenu.val()
      @updateThemeConfig()

    @loadAvailableThemes()

  # Populate the theme menus from the theme manager's active themes
  populateThemeMenus: ->
    @uiMenu.empty()
    @syntaxMenu.empty()
    for name in atom.themes.getAvailableNames().sort()
      themeItem = @createThemeMenuItem(name)
      if /-ui/.test(name)
        themeItem.prop('selected', true) if name is @activeUiTheme
        @uiMenu.append(themeItem)
      else
        themeItem.prop('selected', true) if name is @activeSyntaxTheme
        @syntaxMenu.append(themeItem)

  # Get the name of the active ui theme.
  getActiveUiTheme: ->
    for name in atom.themes.getActiveNames()
      return name if /-ui/.test(name)
    null

  # Get the name of the active syntax theme.
  getActiveSyntaxTheme: ->
    for name in atom.themes.getActiveNames()
      return name unless /-ui/.test(name)
    null

  # Update the config with the selected themes
  updateThemeConfig: ->
    setTimeout =>
      themes = []
      themes.push(@activeUiTheme) if @activeUiTheme
      themes.push(@activeSyntaxTheme) if @activeSyntaxTheme
      atom.themes.setEnabledThemes(themes) if themes.length > 0
    , 100

  # Create a menu item for the given theme name.
  createThemeMenuItem: (themeName) ->
    title = @getThemeTitle(themeName)
    $$ -> @option value: themeName, title

  # Get a human readable title for the given theme name.
  getThemeTitle: (themeName='') ->
    title = themeName.replace(/-(ui|syntax)/g, '')
    _.undasherize(_.uncamelcase(title))

  # Load and display themes available to install.
  loadAvailableThemes: ->
    @loadingMessage.show()
    @emptyMessage.hide()

    @packageManager.getAvailable (error, packages=[]) =>
      installedThemes = atom.themes.getAvailableNames()
      themes = packages.filter ({name, theme}) ->
        theme and not (name in installedThemes)

      @loadingMessage.hide()
      if themes.length > 0
        for theme in themes
          @themeRow.append(new AvailablePackageView(theme, @packageManager))
      else
        @emptyMessage.show() unless error?
