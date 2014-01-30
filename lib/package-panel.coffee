path = require 'path'

{View} = require 'atom'
_ = require 'underscore-plus'
fs = require 'fs-plus'
shell = require 'shell'

PackageKeymapView = require './package-keymap-view'
SettingsPanel = require './settings-panel'

module.exports =
class PackagePanel extends View
  @content: ->
    @form class: 'package-panel', =>
      @h3 =>
        @span outlet: 'title', class: 'title'
        @span ' '
        @span outlet: 'version', class: 'label label-primary'
        @span ' '
        @span outlet: 'disabledLabel', class: 'label label-warning', 'Disabled'
      @p outlet: 'description', class: 'description'
      @p outlet: 'startupTime', class: 'startup-time icon icon-dashboard'
      @div outlet: 'buttons', class: 'btn-group', =>
        @button outlet: 'disableButton', class: 'btn btn-default icon'
        @button outlet: 'homepageButton', class: 'btn btn-default icon icon-home', 'Visit Homepage'
        @button outlet: 'issueButton', class: 'btn btn-default icon icon-bug', 'Report Issue'
        @button outlet: 'readmeButton', class: 'btn btn-default icon icon-book', 'Open README'

  initialize: (@pack) ->
    @title.text("#{_.undasherize(_.uncamelcase(@pack.name))}")

    packageType = if @pack.metadata.theme then 'theme' else 'package'
    @startupTime.text("This #{packageType} added #{@getStartupTime()}ms to startup time.")

    @description.text(@pack.metadata.description)
    @version.text(@pack.metadata.version)
    @disableButton.hide() if @pack.metadata.theme
    @append(new SettingsPanel(@pack.name, {includeTitle: false}))
    @append(new PackageKeymapView(@pack.name))
    @handleButtonEvents()
    @updateEnablement()

  handleButtonEvents: ->
    @disableButton.on 'click', =>
      if atom.packages.isPackageDisabled(@pack.name)
        atom.packages.enablePackage(@pack.name)
      else
        atom.packages.disablePackage(@pack.name)
      @updateEnablement()
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

  updateEnablement: ->
    if atom.packages.isPackageDisabled(@pack.name)
      @disableButton.text('Enable')
      @disableButton.addClass('icon-playback-play')
      @disableButton.removeClass('icon-playback-pause')
      @disabledLabel.show()
    else
      @disableButton.text('Disable')
      @disableButton.addClass('icon-playback-pause')
      @disableButton.removeClass('icon-playback-play')
      @disabledLabel.hide()

  getStartupTime: ->
    loadTime = @pack.loadTime ? 0
    activateTime = @pack.activateTime ? 0
    loadTime + activateTime

  getRepositoryUrl: ->
    repository = @pack.metadata.repository
    url = repository.url ? repository ? ''
    url.replace(/\.git$/, '').replace(/\/$/, '')
