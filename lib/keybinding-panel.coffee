{$$, $$$, View} = require 'atom'

module.exports =
class KeybindingPanel extends View
  @content: ->
    @div class: 'keybinding-panel section', =>
      @h1 class: 'section-heading', 'Keybindings'
      @table =>
        @thead =>
          @tr =>
            @th "Source"
            @th "Keys"
            @th "Command"
            @th "Selector"
        @tbody outlet: 'keybindingRows'

  initialize: ->
    @appendKeybindings()

  appendKeybindings: ->
    for {selector, keystrokes, command, source} in global.keymap.getAllKeyMappings()
      @keybindingRows.append @elementForKeybinding(selector, keystrokes, command, source)

  elementForKeybinding: (selector, keystroke, command, source) ->
    $$$ ->
      @tr =>
        @td source
        @td keystroke
        @td command
        @td selector
