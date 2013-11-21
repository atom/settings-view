{_, $, $$, Editor, View} = require 'atom'

###
# Internal #
###

module.exports =
class GeneralPanel extends View
  @content: ->
    @form id: 'general-panel', =>
      @div outlet: "loadingElement", class: 'alert alert-info loading-area icon icon-hourglass', "Loading settings"

  initialize: ->
    @loadingElement.remove()
    @appendSettings(name, settings) for name, settings of atom.config.getSettings()
    @bindFormFields()
    @bindEditors()

  appendSettings: (namespace, settings) ->
    return if _.isEmpty(settings)

    @append $$ ->
      @section class: 'bordered', =>
        @h1 class: 'section-heading', "#{_.uncamelcase(namespace)} settings"
        appendSetting.call(this, namespace, name, value) for name, value of settings

  bindFormFields: ->
    for input in @find('input[id]').toArray()
      do (input) =>
        input = $(input)
        name = input.attr('id')
        type = input.attr('type')

        @observeConfig name, (value) ->
          if type is 'checkbox'
            input.prop('checked', value)
          else
            input.val(value) if value

        input.on 'change', =>
          value = input.val()
          if type == 'checkbox'
            value = !!input.prop('checked')
          else
            value = @parseValue(type, value)

          atom.config.set(name, value)

  bindEditors: ->
    for editor in @find('input[id]')
      editor = $(editor)
      do (editor) =>
        name = editor.attr('id')
        type = editor.attr('data-type')

        @observeConfig name, (value) =>
          stringValue = @valueToString(value)
          return if stringValue == editor.val()
          stringValue ?= ""
          editor.val(stringValue)

        editor.on 'keyup', =>
          atom.config.set(name, @parseValue(type, editor.val()))

  valueToString: (value) ->
    if _.isArray(value)
      value.join(", ")
    else
      value?.toString()

  parseValue: (type, value) ->
    if value == ''
      value = undefined
    else if type == 'int'
      intValue = parseInt(value)
      value = intValue unless isNaN(intValue)
    else if type == 'float'
      floatValue = parseFloat(value)
      value = floatValue unless isNaN(floatValue)
    else if type == 'array'
      arrayValue = (value or '').split(',')
      value = (val.trim() for val in arrayValue when val)

    value

###
# Space Pen Helpers
###

appendSetting = (namespace, name, value) ->
  return if namespace is 'core' and name is 'themes' # Handled in the Themes panel
  return if namespace is 'core' and name is 'disabledPackages' # Handled in the Packages panel

  @div class: 'control-group', =>
    @div class: 'controls', =>
      if _.isBoolean(value)
        appendCheckbox.call(this, namespace, name, value)
      else if _.isArray(value)
        appendArray.call(this, namespace, name, value)
      else
        appendEditor.call(this, namespace, name, value)

appendCheckbox = (namespace, name, value) ->
  englishName = _.uncamelcase(name)
  keyPath = "#{namespace}.#{name}"
  @div class: 'checkbox', =>
    @label for: keyPath, =>
      @input id: keyPath, type: 'checkbox'
      @text englishName

appendEditor = (namespace, name, value) ->
  englishName = _.uncamelcase(name)
  keyPath = "#{namespace}.#{name}"
  if _.isNumber(value)
    type = if value % 1 == 0 then 'int' else 'float'
  else
    type = 'string'

  @label class: 'control-label', englishName
  @div class: 'controls', =>
    @input id: keyPath, type: 'text', value: keyPath.replace('.', ''), 'data-type': type

appendArray = (namespace, name, value) ->
  englishName = _.uncamelcase(name)
  keyPath = "#{namespace}.#{name}"
  @label class: 'control-label', englishName
  @div class: 'controls', =>
    @input id: keyPath, type: 'text', value: keyPath.replace('.', ''), 'data-type': 'array'
