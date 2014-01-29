_ = require 'underscore-plus'
{$$, View} = require 'atom'

module.exports =
class ThemeConfigPanel extends View
  @content: ->
    @div =>
      @div class: 'section themes', =>
        @div class: 'section-heading theme-heading icon icon-device-desktop', 'Choose a Theme'

        @div class: 'text padded', =>
          @span class: 'icon icon-question', 'You can also style Atom by editing '
          @a class: 'link', outlet: 'openUserStysheet', 'your stylesheet'

        @form class: 'form-horizontal theme-chooser', =>
          @div class: 'form-group', =>
            @label class: 'control-label themes-label', 'UI Theme'
            @div class: 'col-lg-4', =>
              @select outlet: 'uiMenu', class: 'form-control'
              @div class: 'text theme-description', 'This styles the tabs, status bar, tree view, and dropdowns'

          @div class: 'form-group', =>
            @label class: 'control-label themes-label', 'Syntax Theme'
            @div class: 'col-lg-4', =>
              @select outlet: 'syntaxMenu', class: 'form-control'
              @div class: 'text theme-description', 'This styles the code inside the editor'

      @div class: 'section themes', =>
        @div class: 'section-heading theme-heading icon icon-cloud-download', 'Install More Themes'

  initialize: ->
    @openUserStysheet.on 'click', =>
      atom.workspaceView.trigger('application:open-your-stylesheet')
      false

    @observeConfig 'core.themes', =>
      @activeUiTheme = @getActiveUiTheme()
      @activeSyntaxTheme = @getActiveSyntaxTheme()

      @uiMenu.empty()
      @syntaxMenu.empty()
      for name in atom.themes.getAvailableNames()
        themeItem = @createThemeMenuItem(name)
        if /-ui/.test(name)
          themeItem.prop('selected', true) if name is @activeUiTheme
          @uiMenu.append(themeItem)
        else
          themeItem.prop('selected', true) if name is @activeSyntaxTheme
          @syntaxMenu.append(themeItem)

    @syntaxMenu.change =>
      @activeSyntaxTheme = @syntaxMenu.val()
      @updateThemeConfig()

    @uiMenu.change =>
      @activeUiTheme = @uiMenu.val()
      @updateThemeConfig()

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
