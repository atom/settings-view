{$$$, View, EditorView} = require 'atom'
_ = require 'underscore-plus'
path = require 'path'

module.exports =
class KeybindingPanel extends View
  @content: ->
    @div class: 'keybinding-panel section', =>
      @div class: 'section-heading icon icon-keyboard', 'Keybindings'
      @div class: 'text padded', =>
        @span 'You can change these keybindings by editing '
        @a class: 'link', outlet: 'openUserKeymap', 'your keymap file'

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
    @openUserKeymap.on 'click', =>
      atom.workspaceView.trigger('application:open-your-keymap')
      false

    @filter.setPlaceholderText('Search')
    @keyBindings = _.sortBy(atom.keymap.getKeyBindings(), 'keystroke')
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

    if filePath.indexOf(path.join(atom.getLoadSettings().resourcePath, 'keymaps')) is 0
      'Core'
    else if filePath is atom.keymap.getUserKeymapPath()
      'User'
    else
      pathParts = filePath.split(path.sep)
      packageNameIndex = pathParts.length - 3
      _.undasherize(_.uncamelcase(pathParts[packageNameIndex]))
