{_, $, $$, View} = require 'atom'

module.exports =
class ThemeConfigPanel extends View
  @content: ->
    @div class: 'section themes', =>
      @div class: 'section-heading theme-heading icon icon-device-desktop', 'Pick a Theme'
      @div class: 'text padded', """
        Atom supports two types of themes, UI and syntax. UI themes style
        elements such as the tabs, status bar, and tree view.  Syntax themes
        style the code inside the editor.
      """

      @div =>
        @div class: 'ui-themes padded', =>
          @span class: 'btn btn themes-label', 'UI Theme:'
          @div class: 'btn-group', =>
            @button class: 'btn btn dropdown-toggle theme-dropdown', 'data-toggle': 'dropdown', =>
              @span outlet: 'selectedUiTheme'
              @span class: 'caret'
            @ul outlet: 'uiMenu', class: 'dropdown-menu theme-menu'

        @div class: 'syntax-themes padded', =>
          @span class: 'btn themes-label', 'Syntax Theme:'
          @div class: 'btn-group', =>
            @button type: 'button', class: 'btn dropdown-toggle theme-dropdown', 'data-toggle': 'dropdown', =>
              @span outlet: 'selectedSyntaxTheme'
              @span class: 'caret'
            @ul outlet: 'syntaxMenu', class: 'dropdown-menu theme-menu', role: 'menu'

      @div class: 'text padded', =>
        @span class: 'icon icon-question', 'You can also style Atom by editing '
        @a class: 'link', outlet: 'openUserStysheet', 'your stylesheet'

  initialize: ->
    @openUserStysheet.on 'click', =>
      atom.workspaceView.trigger('application:open-your-stylesheet')
      false

    @observeConfig 'core.themes', =>
      @activeUiTheme = @getActiveUiTheme()
      @activeSyntaxTheme = @getActiveSyntaxTheme()
      @selectActiveThemes()

      @uiMenu.empty()
      @syntaxMenu.empty()
      for name in atom.themes.getAvailableNames()
        themeItem = @createThemeMenuItem(name)
        if /-ui/.test(name)
          themeItem.addClass('active-theme') if name is @activeUiTheme
          @uiMenu.append(themeItem)
        else
          themeItem.addClass('active-theme') if name is @activeSyntaxTheme
          @syntaxMenu.append(themeItem)

    @syntaxMenu.on 'click', ({target}) =>
      @activeSyntaxTheme = $(target).data('themeName')
      @changeThemes()
      false

    @uiMenu.on 'click', ({target}) =>
      @activeUiTheme = $(target).data('themeName')
      @changeThemes()
      false

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

  # Update the UI and config with the newly selected themes.
  changeThemes: ->
    @closeDropdown()
    @selectActiveThemes()

    # Perform in a next tick so the dropdown and active theme buttons get
    # a chance to update before the pause that occurs reloading the stylesheets.
    process.nextTick => @updateThemeConfig()

  # Close all dropdowns currently open.
  closeDropdown: ->
    @find('.open').removeClass('open')

  # Update the config with the selected themes
  updateThemeConfig: ->
    themes = []
    themes.push(@activeUiTheme) if @activeUiTheme
    themes.push(@activeSyntaxTheme) if @activeSyntaxTheme
    atom.themes.setEnabledThemes(themes) if themes.length > 0

  # Populate the theme buttons with the active theme titles
  selectActiveThemes: ->
    @selectedSyntaxTheme.text(@getThemeTitle(@activeSyntaxTheme))
    @selectedUiTheme.text(@getThemeTitle(@activeUiTheme))

  # Create a menu item for the given theme name.
  createThemeMenuItem: (themeName) ->
    title = @getThemeTitle(themeName)
    $$ ->
      @li =>
        @a class: 'icon icon-check hidden-icon', 'data-theme-name': themeName, href: '#', title

  # Get a human readable title for the given theme name.
  getThemeTitle: (themeName='') ->
    title = themeName.replace(/-(ui|syntax)/g, '')
    _.undasherize(_.uncamelcase(title))
