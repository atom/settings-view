path = require 'path'

{_, fs, View} = require 'atom'
roaster = require 'roaster'
shell = require 'shell'

PackageKeymapView = require './package-keymap-view'
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
        @button outlet: 'disableButton', class: 'btn btn-default icon icon-playback-pause', 'Disable'
        @button outlet: 'homepageButton', class: 'btn btn-default icon icon-home', 'Visit Homepage'
        @button outlet: 'issueButton', class: 'btn btn-default icon icon-bug', 'Report Issue'
        @button outlet: 'readmeButton', class: 'btn btn-default icon icon-book', 'View README'

  initialize: (@pack) ->
    @title.text("#{_.undasherize(_.uncamelcase(@pack.name))}")
    @description.text(@pack.metadata.description)
    @version.text(@pack.metadata.version)
    @append(new SettingsPanel(@pack.name, {includeTitle: false}))
    @append(new PackageKeymapView(@pack.name))
    @handleButtonEvents()

  handleButtonEvents: ->
    @disableButton.on 'click', =>
      if atom.packages.isPackageDisabled(@pack.name)
        atom.packages.enablePackage(@pack.name)
      else
        atom.packages.disablePackage(@pack.name)
      false

    @homepageButton.on 'click', =>
      if repoUrl = @getRepositoryUrl()
        shell.openExternal(repoUrl)
      false

    @issueButton.on 'click', =>
      if repoUrl = @getRepositoryUrl()
        shell.openExternal("#{repoUrl}/issues/new")
      false

    @readmeButton.on 'click', =>
      for child in fs.listSync(@pack.path)
        extension = path.extname(child)
        name = path.basename(child, extension)
        if name.toLowerCase() is 'readme'
          atom.workspaceView.open(child)
          break
      false

  getRepositoryUrl: ->
    repository = @pack.metadata.repository
    url = repository.url ? repository ? ''
    url.replace(/\.git$/, '').replace(/\/$/, '')
