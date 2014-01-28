{_, $, $$$, View, EditorView} = require 'atom'
path = require 'path'

module.exports =
class KeybindingPanel extends View
  @content: ->
    @div class: 'keybinding-panel section', =>
      @h2 class: 'section-heading icon icon-keyboard', 'Keybindings'
      @div class: 'editor-container', =>
        @subview 'filter', new EditorView(mini: true)
      @table class: 'native-key-bindings table', tabindex: -1, =>
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
    @filter.setPlaceholderText('Search')
    @keyBindings = _.sortBy(atom.keymap.getKeyBindings(), (x) -> x.keystroke)
    @appendKeyBindings(@keyBindings)

    @filter.getEditor().getBuffer().on 'contents-modified', =>
      @filterKeyBindings(@keyBindings, @filter.getText())

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
    else if filePath is path.join(atom.getConfigDirPath(), 'keymap.json') or filePath is path.join(atom.getConfigDirPath(), 'keymap.cson')
      'User'
    else
      packageNameIndex = pathParts.length - 3
      pathParts[packageNameIndex]
