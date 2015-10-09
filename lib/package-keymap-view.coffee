path = require 'path'
_ = require 'underscore-plus'
{$, $$$, View} = require 'atom-space-pen-views'
KeybindingsPanel = require './keybindings-panel'

# Displays the keybindings for a package namespace
module.exports =
class PackageKeymapView extends View
  @content: ->
    @section class: 'section', =>
      @div class: 'section-heading icon icon-keyboard', 'Keybindings'
      @div class: 'checkbox', =>
        @label for: 'toggleKeybindings', =>
          @input id: 'toggleKeybindings', type: 'checkbox', outlet: 'keybindingToggle'
          @div class: 'setting-title', 'Enable'
        @div class: 'setting-description', 'Disable this if you want to bind your own keystrokes for this package\'s commands in your keymap.'
      @table class: 'package-keymap-table table native-key-bindings text', tabindex: -1, =>
        @thead =>
          @tr =>
            @th 'Keystroke'
            @th 'Command'
            @th 'Selector'
            @th 'Source'
        @tbody outlet: 'keybindingItems'

  initialize: (@pack) ->
    @otherPlatformPattern = new RegExp("\\.platform-(?!#{_.escapeRegExp(process.platform)}\\b)")
    @namespace = @pack.name

    @keybindingToggle.prop('checked', not _.include(atom.config.get('core.packagesWithKeymapsDisabled') ? [], @namespace))

    @keybindingToggle.on 'change', (event) =>
      event.stopPropagation()
      value = !!@keybindingToggle.prop('checked')
      if value
        atom.config.removeAtKeyPath('core.packagesWithKeymapsDisabled', @namespace)
      else
        atom.config.pushAtKeyPath('core.packagesWithKeymapsDisabled', @namespace)

      @updateKeyBindingView()

    @updateKeyBindingView()

    hasKeymaps = false
    for [packageKeymapsPath, map] in atom.packages.getLoadedPackage(@namespace).keymaps
      if map.length > 0
        hasKeymaps = true
        break

    @hide() unless @keybindingItems.children().length > 0 or hasKeymaps

  updateKeyBindingView: ->
    @keybindingItems.empty()

    for keyBinding in atom.keymaps.getKeyBindings()
      {command, keystrokes, selector, source} = keyBinding
      continue unless command?.indexOf?("#{@namespace}:") is 0
      continue if @otherPlatformPattern.test(selector)

      keyBindingView = $$$ ->
        @tr =>
          @td =>
            @span class: 'icon icon-clippy copy-icon'
            @span keystrokes
          @td command
          @td selector
          @td KeybindingsPanel.determineSource(source)
      keyBindingView = $(keyBindingView)
      keyBindingView.data('keyBinding', keyBinding)

      @keybindingItems.append(keyBindingView)

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
