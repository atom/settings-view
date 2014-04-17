{EditorView} = require 'atom'

module.exports =
class SettingEditorView extends EditorView
  constructor: (options={}) ->
    options.mini = true
    super(options)

  setFontSize: (fontSize) ->
    fontSize = parseInt(fontSize) or 0
    fontSize = Math.min(32, fontSize)
    fontSize = Math.max(10, fontSize)
    super(fontSize)
