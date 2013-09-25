{$$, $$$, View} = require 'atom'

module.exports =
class KeybindingPanel extends View
  @content: ->
    @div class: 'keybinding-panel section', =>
      @h1 class: 'section-heading', 'Keybindings'
      @table =>
        @thead =>
          @tr =>
            @th "Keys"
            @th "Selector"
            @th "Command"
        @tbody outlet: 'keybindingRows'

  initialize: ->
    @appendKeybindings()

  appendKeybindings: ->
    for bindingSet in global.keymap.getBindingSets()
      selector = bindingSet.getSelector()
      for keystrokes, command of bindingSet.getCommandsByKeystrokes()
        @keybindingRows.append @elementForKeybinding(selector, keystrokes, command)

  elementForKeybinding: (selector, keystroke, command) ->
    $$$ ->
      @tr =>
        @td keystroke
        @td selector
        @td command
