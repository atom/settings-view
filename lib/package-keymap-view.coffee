{$$$, View} = require 'atom'

# Displays the keybindings for a package namespace
module.exports =
class PackageKeymapView extends View
  @content: ->
    @section =>
      @div class: 'section-heading icon icon-keyboard', 'Keybindings'
      @table class: 'package-keymap-table table native-key-bindings text', tabindex: -1, =>
        @thead =>
          @tr =>
            @th 'Keystroke'
            @th 'Command'
            @th 'Selector'
        @tbody outlet: 'keybindingItems'

  initialize: (namespace) ->
    for {command, keystroke, selector} in atom.keymap.getKeyBindings()
      continue unless command?.indexOf?("#{namespace}:") is 0

      @keybindingItems.append $$$ ->
        @tr =>
          @td keystroke
          @td command
          @td selector

    @hide() unless @keybindingItems.children().length > 0
