{_, $, $$$, View, Editor} = require 'atom'

module.exports =
class KeybindingPanel extends View
  @content: ->
    @div class: 'keybinding-panel section', =>
      @h1 class: 'section-heading', 'Keybindings'
      @div class: 'block', =>
        @label 'Filter:'
        @subview 'filter', new Editor(mini: true)
      @table =>
        @col class: 'keystroke'
        @col class: 'command'
        @col class: 'source'
        @col class: 'selector'
        @thead =>
          @tr =>
            @th class: 'keystroke', 'Keystroke'
            @th class: 'command', 'Command'
            @th class: 'source', 'Source'
            @th class: 'selector', 'Selector'
        @tbody outlet: 'keybindingRows'

  initialize: ->
    @keyMappings = _.sortBy(global.keymap.getAllKeyMappings(), (x) -> x.keystroke)
    @appendKeyMappings(@keyMappings)

    @filter.getBuffer().on 'contents-modified', =>
      @filterKeyMappings(@keyMappings, @filter.getText())

  filterKeyMappings: (keyMappings, filterString) ->
    @keybindingRows.empty()
    for keyMapping in keyMappings
      {selector, keystroke, command, source} = keyMapping
      searchString = "#{selector}#{keystroke}#{command}#{source}"
      continue unless searchString

      if /^\s*$/.test(filterString) or searchString.indexOf(filterString) != -1
        @keybindingRows.append @elementForKeyMapping(keyMapping)

  appendKeyMappings: (keyMappings) ->
    for keyMapping in keyMappings
      @keybindingRows.append @elementForKeyMapping(keyMapping)

  elementForKeyMapping: (keyMapping) ->
    {selector, keystroke, command, source} = keyMapping
    $$$ ->
      @tr =>
        @td class: 'keystroke', keystroke
        @td class: 'command', command
        @td class: 'source', source
        @td class: 'selector', selector
