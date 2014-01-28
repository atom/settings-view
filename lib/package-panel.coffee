shell = require 'shell'
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
        @button outlet: 'disableButton', class: 'btn btn-default', 'Disable'
        @button outlet: 'homepageButton', class: 'btn btn-default', 'Visit Homepage'
        @button outlet: 'issueButton', class: 'btn btn-default', 'Report Issue'

  initialize: (@pack) ->
    @title.text("#{_.undasherize(_.uncamelcase(@pack.name))}")
    @description.text(@pack.metadata.description)
    @version.text(@pack.metadata.version)
    @append(new SettingsPanel(@pack.name, {includeTitle: false}))
    @handleButtonEvents()

  handleButtonEvents: ->
    @disableButton.on 'click', =>
      if atom.packages.isPackageDisabled(@pack.name)
        atom.packages.enablePackage(@pack.name)
      else
        atom.packages.disablePackage(@pack.name)

    @homepageButton.on 'click', =>
      if repoUrl = @getRepositoryUrl()
        shell.openExternal(repoUrl)
      false

    @issueButton.on 'click', =>
      if repoUrl = @getRepositoryUrl()
        shell.openExternal("#{repoUrl}/issues/new")
      false

  getRepositoryUrl: ->
    repository = @pack.metadata.repository
    url = repository.url ? repository ? ''
    url.replace(/\.git$/, '').replace(/\/$/, '')
