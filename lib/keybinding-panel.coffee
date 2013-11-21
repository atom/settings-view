{_, $, $$$, View, Editor} = require 'atom'
path = require 'path'

module.exports =
class KeybindingPanel extends View
  @content: ->
    @div class: 'keybinding-panel section', =>
      @h1 class: 'section-heading', 'Keybindings'
      @div class: 'block', =>
        @label 'Filter:'
        @input type: 'text', outlet: 'bindingFilter'
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
    @keyBindings = _.sortBy(atom.keymap.getKeyBindings(), (x) -> x.keystroke)
    @appendKeyBindings(@keyBindings)

    @bindingFilter.on 'keyup', =>
      @filterKeyBindings(@keyBindings, @bindingFilter.val())

  filterKeyBindings: (keyBindings, filterString) ->
    @keybindingRows.empty()
    for keyBinding in keyBindings
      {selector, keystroke, command, source} = keyBinding
      searchString = "#{selector}#{keystroke}#{command}#{source}"
      continue unless searchString

      if /^\s*$/.test(filterString) or searchString.indexOf(filterString) != -1
        @keybindingRows.append @elementForKeyBinding(keyBinding)

  appendKeyBindings: (keyBindings) ->
    for keyBinding in keyBindings
      @keybindingRows.append @elementForKeyBinding(keyBinding)

  elementForKeyBinding: (keyBinding) ->
    {selector, keystroke, command, source} = keyBinding
    source = @determineSource(source)
    $$$ ->
      @tr =>
        @td class: 'keystroke', keystroke
        @td class: 'command', command
        @td class: 'source', source
        @td class: 'selector', selector

    # Private: Returns a user friendly description of where a keybinding was
  # loaded from.
  #
  # * filePath:
  #   The absolute path from which the keymap was loaded
  #
  # Returns one of:
  # * `Core` indicates it comes from a bundled package.
  # * `User` indicates that it was defined by a user.
  # * `<package-name>` the package which defined it.
  # * `Unknown` if an invalid path was passed in.
  determineSource: (filePath) ->
    return 'Unknown' unless filePath

    pathParts = filePath.split(path.sep)
    if _.contains(pathParts, 'node_modules') or _.contains(pathParts, 'atom') or _.contains(pathParts, 'src')
      'Core'
    else if _.contains(pathParts, '.atom') and _.contains(pathParts, 'keymaps') and !_.contains(pathParts, 'packages')
      'User'
    else
      packageNameIndex = pathParts.length - 3
      pathParts[packageNameIndex]
