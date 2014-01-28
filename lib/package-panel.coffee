{_, View} = require 'atom'
SettingsPanel = require './settings-panel'

module.exports =
class PackagePanel extends View
  @content: ->
    @form class: 'package-panel', =>
      @h2 =>
        @span outlet: 'title', class: 'title'
        @span ' '
        @span outlet: 'version', class: 'label label-primary'
      @p outlet: 'description', class: 'description'
      @div outlet: 'buttons', class: 'btn-group', =>
        @button class: 'btn btn-default', 'Disable'
        @button class: 'btn btn-default', 'Visit Homepage'
        @button class: 'btn btn-default', 'Report Issue'

  initialize: (@pack) ->
    @title.text("#{_.undasherize(_.uncamelcase(@pack.name))}")
    @description.text(@pack.metadata.description)
    @version.text(@pack.metadata.version)
    @append(new SettingsPanel(@pack.name, {includeTitle: false}))
