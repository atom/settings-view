{$$$, View} = require 'atom'

# Displays the keybindings for a package namespace
module.exports =
class PackageKeymapView extends View
  @content: ->
    @section class: 'package-keymap', =>
      @div class: 'section-heading package-keymap-heading icon icon-keyboard', 'Keybindings'
      @table outlet: 'keymapTable', class: 'package-keymap-table table native-key-bindings', tabindex: -1, =>
        @thead =>
          @tr =>
            @th 'Keystroke'
            @th 'Command'
            @th 'Selector'
        @tbody outlet: 'keybindingItems'

  initialize: (namespace) ->
    for {command, keystroke, selector} in atom.keymap.getKeyBindings()
      continue unless command.indexOf("#{namespace}:") is 0

      @keybindingItems.append $$$ ->
        @tr class: 'package-keymap-item', =>
          @td class: 'keystroke', keystroke
          @td class: 'command', command
          @td class: 'selector', selector

    @hide() unless @keybindingItems.children().length > 0
