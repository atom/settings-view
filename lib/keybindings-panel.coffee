{$, $$$, View, EditorView} = require 'atom'
_ = require 'underscore-plus'
path = require 'path'

module.exports =
class KeybindingsPanel extends View
  @content: ->
    @div class: 'keybinding-panel section', =>
      @div class: 'section-heading icon icon-keyboard', 'Keybindings'

      @div class: 'text padded', =>
        @span class: 'icon icon-question'
        @span 'You can override these keybindings by copying '
        @span class: 'icon icon-clippy'
        @span 'and pasting them into '
        @a class: 'link', outlet: 'openUserKeymap', 'your keymap file'

      @div class: 'editor-container padded', =>
        @subview 'searchEditorView', new EditorView(mini: true)

      @table class: 'native-key-bindings table text', tabindex: -1, =>
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

    @searchEditorView.setPlaceholderText('Search keybindings')
    @keyBindings = _.sortBy(atom.keymap.getKeyBindings(), 'keystroke')
    @appendKeyBindings(@keyBindings)

    @searchEditorView.getEditor().getBuffer().on 'contents-modified', =>
      @filterKeyBindings(@keyBindings, @searchEditorView.getText())

    @on 'click', '.copy-icon', ({target}) =>
      keyBinding = $(target).closest('tr').data('keyBinding')
      @writeKeyBindingToClipboard(keyBinding)

  focus: ->
    @searchEditorView.focus()

  filterKeyBindings: (keyBindings, filterString) ->
    @keybindingRows.empty()
    for keyBinding in keyBindings
      {selector, keystroke, command, source} = keyBinding
      searchString = "#{selector}#{keystroke}#{command}#{source}"
      continue unless searchString

      if /^\s*$/.test(filterString) or searchString.indexOf(filterString) != -1
        @appendKeyBinding(keyBinding)

  appendKeyBindings: (keyBindings) ->
    @appendKeyBinding(keyBinding) for keyBinding in keyBindings

  appendKeyBinding: (keyBinding) ->
    view = $(@elementForKeyBinding(keyBinding))
    view.data('keyBinding', keyBinding)
    @keybindingRows.append(view)

  elementForKeyBinding: (keyBinding) ->
    {selector, keystroke, command, source} = keyBinding
    source = @determineSource(source)
    $$$ ->
      rowClasses = if source is 'User' then 'success' else ''
      @tr class: rowClasses, =>
        @td class: 'keystroke', =>
          @span class: 'icon icon-clippy copy-icon'
          @span keystroke
        @td class: 'command', command
        @td class: 'source', source
        @td class: 'selector', selector

  writeKeyBindingToClipboard: ({selector, keystroke, command}) ->
    keymapExtension = path.extname(atom.keymap.getUserKeymapPath())
    if keymapExtension is '.cson'
      content = """
        '#{selector}':
          '#{keystroke}': '#{command}'
      """
    else
      content = """
        "#{selector}": {
          "#{keystroke}": "#{command}"
        }
      """
    atom.clipboard.write(content)

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
      packageName = pathParts[packageNameIndex] ? ''
      _.undasherize(_.uncamelcase(packageName))
