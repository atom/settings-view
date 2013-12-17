{_, $, $$, View} = require 'atom'

###
# Internal #
###

window.jQuery = $
require 'jqueryui-browser/ui/jquery.ui.core'
require 'jqueryui-browser/ui/jquery.ui.widget'
require 'jqueryui-browser/ui/jquery.ui.mouse'
require 'jqueryui-browser/ui/jquery.ui.sortable'
require 'jqueryui-browser/ui/jquery.ui.draggable'
delete window.jQuery

module.exports =
class ThemeConfigPanel extends View
  @content: ->
    @div class: 'section themes-config', =>
      @h1 class: 'section-heading', "Themes"
      @p 'Drag themes between the Available Themes and the Enabled Themes sections'
      @div class: 'theme-picker', =>
        @div class: 'panel', =>
          @div class: 'panel-heading', "Enabled Themes"
          @ol class: 'enabled-themes list-group', outlet: 'enabledThemes'

        @div class: 'panel', =>
          @div class: 'panel-heading', "Available Themes"
          @ol class: 'available-themes list-group', outlet: 'availableThemes'

  constructor: ->
    super
    for name in atom.themes.getAvailableNames()
      @availableThemes.append(@buildThemeLi(name, draggable: true))

    @observeConfig "core.themes", (enabledThemes) =>
      @enabledThemes.empty()
      for name in enabledThemes ? []
        @enabledThemes.append(@buildThemeLi(name))

    @enabledThemes.sortable
      receive: (e, ui) => @enabledThemeReceived($(ui.helper))
      update: => @enabledThemesUpdated()

    @on "click", ".enabled-themes .disable-theme", (e) =>
      $(e.target).closest('li').remove()
      @enabledThemesUpdated()
      false

  buildThemeLi: (name, {draggable} = {}) ->
    li = $$ ->
      @li class: 'list-item', name: name, =>
        @a href: '#', class: 'icon icon-x disable-theme pull-right'
        @text name
    if draggable
      li.draggable
        connectToSortable: '.enabled-themes'
        appendTo: '.themes-config'
        helper: (e) ->
          target = $(e.target)
          target.clone().width(target.width())
    else
      li

  enabledThemeReceived: (helper) ->
    name = helper.attr('name')
    @enabledThemes.find("[name='#{name}']:not('.ui-draggable')").remove()
    @enabledThemes.find(".ui-draggable").removeClass('ui-draggable')

  enabledThemesUpdated: ->
    atom.themes.setEnabledThemes(@getEnabledThemeNames())

  getEnabledThemeNames: ->
    $(li).attr('name') for li in @enabledThemes.children().toArray()
