path = require 'path'
_ = require 'underscore-plus'
{$, $$$, View} = require 'atom-space-pen-views'

# Displays the keybindings for a package namespace
module.exports =
class PackageKeymapView extends View
  @content: ->
    @section class: 'section', =>
      @div class: 'section-heading icon icon-keyboard', 'Keybindings'
      @table class: 'package-keymap-table table native-key-bindings text', tabindex: -1, =>
        @thead =>
          @tr =>
            @th 'Keystroke'
            @th 'Command'
            @th 'Selector'
        @tbody outlet: 'keybindingItems'

  initialize: (namespace) ->
    otherPlatformPattern = new RegExp("\\.platform-(?!#{_.escapeRegExp(process.platform)}\\b)")

    for keyBinding in atom.keymaps.getKeyBindings()
      {command, keystrokes, selector} = keyBinding
      continue unless command?.indexOf?("#{namespace}:") is 0
      continue if otherPlatformPattern.test(selector)

      keyBindingView = $$$ ->
        @tr =>
          @td =>
            @span class: 'icon icon-clippy copy-icon'
            @span keystrokes
          @td command
          @td selector
      keyBindingView = $(keyBindingView)
      keyBindingView.data('keyBinding', keyBinding)

      @keybindingItems.append(keyBindingView)

    @hide() unless @keybindingItems.children().length > 0

    @on 'click', '.copy-icon', ({target}) =>
      keyBinding = $(target).closest('tr').data('keyBinding')
      @writeKeyBindingToClipboard(keyBinding)

  writeKeyBindingToClipboard: ({selector, keystrokes, command}) ->
    keymapExtension = path.extname(atom.keymaps.getUserKeymapPath())
    if keymapExtension is '.cson'
      content = """
        '#{selector}':
          '#{keystrokes}': '#{command}'
      """
    else
      content = """
        "#{selector}": {
          "#{keystrokes}": "#{command}"
        }
      """
    atom.clipboard.write(content)
