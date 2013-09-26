{_, $, $$$, View, Editor, stringscore} = require 'atom'

module.exports =
class KeybindingPanel extends View
  @content: ->
    @div class: 'keybinding-panel section', =>
      @h1 class: 'section-heading', 'Keybindings'
      @div class: 'block', =>
        @label 'Filter:'
        @subview 'filter', new Editor(mini: true)
      @table =>
        @col class: 'keystrokes'
        @col class: 'command'
        @col class: 'source'
        @col class: 'selector'
        @thead =>
          @tr =>
            @th class: 'keystrokes', 'Keystrokes'
            @th class: 'command', 'Command'
            @th class: 'source', 'Source'
            @th class: 'selector', 'Selector'
        @tbody outlet: 'keybindingRows'

  initialize: ->
    @keyMappings = _.sortBy(global.keymap.getAllKeyMappings(), (x) -> x.keystrokes)
    @appendKeyMappings(@keyMappings)

    @filter.getBuffer().on 'contents-modified', =>
      @filterKeyMappings(@keyMappings, @filter.getText())

  filterKeyMappings: (keyMappings, filterString) ->
    @keybindingRows.empty()
    for keyMapping in keyMappings
      {selector, keystrokes, command, source} = keyMapping
      searchString = "#{selector}#{keystrokes}#{command}#{source}"
      continue unless searchString

      if /^\s*$/.test(filterString) or searchString.indexOf(filterString) != -1
        @keybindingRows.append @elementForKeyMapping(keyMapping)

  appendKeyMappings: (keyMappings) ->
    for keyMapping in keyMappings
      @keybindingRows.append @elementForKeyMapping(keyMapping)

  elementForKeyMapping: (keyMapping) ->
    {selector, keystrokes, command, source} = keyMapping
    $$$ ->
      @tr =>
        @td class: 'keystrokes', keystrokes
        @td class: 'command', command
        @td class: 'source', source
        @td class: 'selector', selector
