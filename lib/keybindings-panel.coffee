{CompositeDisposable} = require 'atom'
{$, $$$, TextEditorView, ScrollView} = require 'atom-space-pen-views'
_ = require 'underscore-plus'
path = require 'path'

module.exports =
class KeybindingsPanel extends ScrollView
  @content: ->
    @div class: 'panels-item', =>
      @section class: 'keybinding-panel section', =>
        @div class: 'section-heading icon icon-keyboard', 'Keybindings'

        @div class: 'text native-key-bindings', tabindex: -1, =>
          @span class: 'icon icon-question'
          @span 'You can override these keybindings by copying '
          @span class: 'icon icon-clippy'
          @span 'and pasting them into '
          @a class: 'link', outlet: 'openUserKeymap', 'your keymap file'

        @div class: 'editor-container', =>
          @subview 'searchEditorView', new TextEditorView(mini: true)

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
    super
    @disposables = new CompositeDisposable()
    @otherPlatformPattern = new RegExp("\\.platform-(?!#{_.escapeRegExp(process.platform)}\\b)")
    @platformPattern = new RegExp("\\.platform-#{_.escapeRegExp(process.platform)}\\b")

    @openUserKeymap.on 'click', ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'application:open-your-keymap')
      false

    @searchEditorView.getModel().setPlaceholderText('Search keybindings')

    @searchEditorView.getModel().onDidStopChanging =>
      @filterKeyBindings(@keyBindings, @searchEditorView.getText())

    @on 'click', '.copy-icon', ({target}) =>
      keyBinding = $(target).closest('tr').data('keyBinding')
      @writeKeyBindingToClipboard(keyBinding)

    @disposables.add atom.keymaps.onDidReloadKeymap => @loadKeyBindings()
    @disposables.add atom.keymaps.onDidUnloadKeymap => @loadKeyBindings()

    @loadKeyBindings()

  dispose: ->
    @disposables.dispose()

  loadKeyBindings: ->
    @keybindingRows.empty()
    @keyBindings = _.sortBy(atom.keymaps.getKeyBindings(), 'keystrokes')
    @appendKeyBindings(@keyBindings)
    @filterKeyBindings(@keyBindings, @searchEditorView.getText())

  focus: ->
    @searchEditorView.focus()

  filterKeyBindings: (keyBindings, filterString) ->
    @keybindingRows.empty()
    for keyBinding in keyBindings
      {selector, keystrokes, command, source} = keyBinding
      searchString = "#{selector}#{keystrokes}#{command}#{source}".toLowerCase()
      continue unless searchString

      if /^\s*$/.test(filterString) or searchString.indexOf(filterString?.toLowerCase()) isnt -1
        @appendKeyBinding(keyBinding)

  appendKeyBindings: (keyBindings) ->
    @appendKeyBinding(keyBinding) for keyBinding in keyBindings

  appendKeyBinding: (keyBinding) ->
    return unless @showSelector(keyBinding.selector)

    view = $(@elementForKeyBinding(keyBinding))
    view.data('keyBinding', keyBinding)
    @keybindingRows.append(view)

  showSelector: (selector) ->
    segments = selector?.split(',') ? []
    return true unless segments

    for segment in segments
      return true if @platformPattern.test(segment)
      return true unless @otherPlatformPattern.test(segment)

    false

  elementForKeyBinding: (keyBinding) ->
    {selector, keystrokes, command, source} = keyBinding
    source = KeybindingsPanel.determineSource(source)
    $$$ ->
      rowClasses = if source is 'User' then 'is-user' else ''
      @tr class: rowClasses, =>
        @td class: 'keystroke', =>
          @span class: 'icon icon-clippy copy-icon'
          @span keystrokes
        @td class: 'command', command
        @td class: 'source', source
        @td class: 'selector', selector

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
  @determineSource: (filePath) ->
    return 'Unknown' unless filePath

    if filePath.indexOf(path.join(atom.getLoadSettings().resourcePath, 'keymaps')) is 0
      'Core'
    else if filePath is atom.keymaps.getUserKeymapPath()
      'User'
    else
      pathParts = filePath.split(path.sep)
      packageNameIndex = pathParts.length - 3
      packageName = pathParts[packageNameIndex] ? ''
      _.undasherize(_.uncamelcase(packageName))
