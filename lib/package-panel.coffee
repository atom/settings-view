{View} = require 'atom'
SettingsPanel = require './settings-panel'

module.exports =
class PackagePanel extends View
  @content: ->
    @form class: 'package-panel'

  initialize: (@pack) ->
    @append(new SettingsPanel(@pack.name))
