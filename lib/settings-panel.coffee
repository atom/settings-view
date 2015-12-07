{CompositeDisposable} = require 'atom'
{$, $$, TextEditorView, View} = require 'atom-space-pen-views'
_ = require 'underscore-plus'

{getSettingDescription} = require './rich-description'

module.exports =
class SettingsPanel extends View
  @content: ->
    @section class: 'section settings-panel'

  initialize: (namespace, @options={}) ->
    @disposables = new CompositeDisposable()
    if @options.scopeName
      namespace = 'editor'
      scopedSettings = [
        'autoIndent'
        'autoIndentOnPaste'
        'invisibles'
        'nonWordCharacters'
        'normalizeIndentOnPaste'
        'preferredLineLength'
        'scrollPastEnd'
        'showIndentGuide'
        'showInvisibles'
        'softWrap'
        'softWrapAtPreferredLineLength'
        'softWrapHangingIndent'
        'tabLength'
      ]
      settings = {}
      for name in scopedSettings
        settings[name] = atom.config.get(name, scope: [@options.scopeName])
    else
      settings = atom.config.get(namespace)

    @appendSettings(namespace, settings)

    @bindInputFields()
    @bindSelectFields()
    @bindEditors()

  dispose: ->
    @disposables.dispose()

  appendSettings: (namespace, settings) ->
    return if _.isEmpty(settings)

    title = @options.title
    includeTitle = @options.includeTitle ? true
    if includeTitle
      title ?= "#{_.undasherize(_.uncamelcase(namespace))} Settings"
    else
      title ?= "Settings"

    icon = @options.icon ? 'gear'
    note = @options.note

    sortedSettings = @sortSettings(namespace, settings)

    @append $$ ->
      @div class: 'section-container', =>
        @div class: "block section-heading icon icon-#{icon}", title
        @raw note if note
        @div class: 'section-body', =>
          for name in sortedSettings
            appendSetting.call(this, namespace, name, settings[name])

  sortSettings: (namespace, settings) ->
    _.chain(settings).keys().sortBy((name) -> name).sortBy((name) -> atom.config.getSchema("#{namespace}.#{name}")?.order).value()

  bindInputFields: ->
    @find('input[id]').toArray().forEach (input) =>
      input = $(input)
      name = input.attr('id')
      type = input.attr('type')

      @observe name, (value) ->
        if type is 'checkbox'
          input.prop('checked', value)
        else
          value = value?.toHexString?() ? value if type is 'color'
          input.val(value) if value

      input.on 'change', =>
        value = input.val()
        if type is 'checkbox'
          value = !!input.prop('checked')
        else
          value = @parseValue(type, value)

        setNewValue = => @set(name, value)
        if type is 'color'
          # This is debounced since the color wheel fires lots of events
          # as you are dragging it around
          clearTimeout(@colorDebounceTimeout)
          @colorDebounceTimeout = setTimeout(setNewValue, 100)
        else
          setNewValue()

  observe: (name, callback) ->
    params = {sources: [atom.config.getUserConfigPath()]}
    params.scope = [@options.scopeName] if @options.scopeName?
    @disposables.add atom.config.observe(name, params, callback)

  isDefault: (name) ->
    params = {sources: [atom.config.getUserConfigPath()]}
    params.scope = [@options.scopeName] if @options.scopeName?
    not atom.config.get(name, params)?

  getDefault: (name) ->
    params = {excludeSources: [atom.config.getUserConfigPath()]}
    params.scope = [@options.scopeName] if @options.scopeName?
    atom.config.get(name, params)

  set: (name, value) ->
    if @options.scopeName
      if value is undefined
        atom.config.unset(name, scopeSelector: @options.scopeName)
      else
        atom.config.set(name, value, scopeSelector: @options.scopeName)
    else
      atom.config.set(name, value)

  bindSelectFields: ->
    @find('select[id]').toArray().forEach (select) =>
      select = $(select)
      name = select.attr('id')

      @observe name, (value) ->
        select.val(value)

      select.change =>
        @set(name, select.val())

  bindEditors: ->
    @find('atom-text-editor[id]').views().forEach (editorView) =>
      editor = editorView.getModel()
      name = editorView.attr('id')
      type = editorView.attr('type')

      if defaultValue = @valueToString(@getDefault(name))
        editor.setPlaceholderText("Default: #{defaultValue}")

      @observe name, (value) =>
        if @isDefault(name)
          stringValue = ''
        else
          stringValue = @valueToString(value) ? ''

        return if stringValue is editor.getText()
        return if _.isEqual(value, @parseValue(type, editor.getText()))

        editorView.setText(stringValue)

      editor.onDidStopChanging =>
        @set(name, @parseValue(type, editor.getText()))

  valueToString: (value) ->
    if _.isArray(value)
      value.join(', ')
    else
      value?.toString()

  parseValue: (type, value) ->
    if value is ''
      value = undefined
    else if type is 'number'
      floatValue = parseFloat(value)
      value = floatValue unless isNaN(floatValue)
    else if type is 'array'
      arrayValue = (value or '').split(',')
      value = (val.trim() for val in arrayValue when val)

    value

###
# Space Pen Helpers
###

isEditableArray = (array) ->
  for item in array
    return false unless _.isString(item)
  true

appendSetting = (namespace, name, value) ->
  if namespace is 'core'
    return if name is 'themes' # Handled in the Themes panel
    return if name is 'disabledPackages' # Handled in the Packages panel
    return if name is 'customFileTypes'

  if namespace is 'editor'
    # There's no global default for these, they are defined by language packages
    return if name in ['commentStart', 'commentEnd', 'increaseIndentPattern', 'decreaseIndentPattern', 'foldEndPattern']

  @div class: 'control-group', =>
    @div class: 'controls', =>
      schema = atom.config.getSchema("#{namespace}.#{name}")
      if schema?.enum
        appendOptions.call(this, namespace, name, value)
      else if schema?.type is 'color'
        appendColor.call(this, namespace, name, value)
      else if _.isBoolean(value) or schema?.type is 'boolean'
        appendCheckbox.call(this, namespace, name, value)
      else if _.isArray(value) or schema?.type is 'array'
        appendArray.call(this, namespace, name, value) if isEditableArray(value)
      else if _.isObject(value) or schema?.type is 'object'
        appendObject.call(this, namespace, name, value)
      else
        appendEditor.call(this, namespace, name, value)

getSettingTitle = (keyPath, name='') ->
  title = atom.config.getSchema(keyPath)?.title
  title or _.uncamelcase(name).split('.').map(_.capitalize).join(' ')

appendOptions = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)
  options = atom.config.getSchema(keyPath)?.enum ? []

  @label class: 'control-label', =>
    @div class: 'setting-title', title
    @div class: 'setting-description', =>
      @raw(description)

  @select id: keyPath, class: 'form-control', =>
    for option in options
      @option value: option, option

appendCheckbox = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)

  @div class: 'checkbox', =>
    @label for: keyPath, =>
      @input id: keyPath, type: 'checkbox'
      @div class: 'setting-title', title
    @div class: 'setting-description', =>
      @raw(description)

appendColor = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)

  @div class: 'color', =>
    @label for: keyPath, =>
      @input id: keyPath, type: 'color'
      @div class: 'setting-title', title
    @div class: 'setting-description', =>
      @raw(description)

appendEditor = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  if _.isNumber(value)
    type = 'number'
  else
    type = 'string'

  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)

  @label class: 'control-label', =>
    @div class: 'setting-title', title
    @div class: 'setting-description', =>
      @raw(description)

  @div class: 'controls', =>
    @div class: 'editor-container', =>
      @subview keyPath.replace(/\./g, ''), new TextEditorView(mini: true, attributes: {id: keyPath, type: type})

appendArray = (namespace, name, value) ->
  keyPath = "#{namespace}.#{name}"
  title = getSettingTitle(keyPath, name)
  description = getSettingDescription(keyPath)

  @label class: 'control-label', =>
    @div class: 'setting-title', title
    @div class: 'setting-description', =>
      @raw(description)

  @div class: 'controls', =>
    @div class: 'editor-container', =>
      @subview keyPath.replace(/\./g, ''), new TextEditorView(mini: true, attributes: {id: keyPath, type: 'array'})

appendObject = (namespace, name, value) ->
  return unless _.keys(value).length

  keyPath = "#{namespace}.#{name}"
  title = getSettingTitle(keyPath, name)
  @div class: 'sub-section', =>
    @div class: 'sub-section-heading', title
    @div class: 'sub-section-body', =>
      for key in _.keys(value).sort()
        appendSetting.call(this, namespace, "#{name}.#{key}", value[key])
