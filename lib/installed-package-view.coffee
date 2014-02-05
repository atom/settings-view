path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
semver = require 'semver'
shell = require 'shell'
{View} = require 'atom'

ErrorView = require './error-view'
PackageGrammarsView = require './package-grammars-view'
PackageKeymapView = require './package-keymap-view'
PackageSnippetsView = require './package-snippets-view'
SettingsPanel = require './settings-panel'

module.exports =
class InstalledPackageView extends View
  @content: ->
    @form class: 'installed-package-view', =>
      @div outlet: 'updateArea', class: 'alert alert-success package-update', =>
        @span outlet: 'updateLabel', class: 'icon icon-squirrel update-message'
        @span outlet: 'updateLink', class: 'alert-link update-link icon icon-cloud-download', 'Install'

      @h3 =>
        @span outlet: 'title', class: 'text'
        @span ' '
        @span outlet: 'version', class: 'label label-primary'
        @span ' '
        @span outlet: 'disabledLabel', class: 'label label-warning', 'Disabled'

      @p outlet: 'description', class: 'text-subtle'
      @p outlet: 'startupTime', class: 'text-subtle icon icon-dashboard'

      @div outlet: 'buttons', class: 'btn-group', =>
        @button outlet: 'disableButton', class: 'btn btn-default icon'
        @button outlet: 'uninstallButton', class: 'btn btn-default icon icon-trashcan', 'Uninstall'
        @button outlet: 'homepageButton', class: 'btn btn-default icon icon-home', 'Visit Homepage'
        @button outlet: 'issueButton', class: 'btn btn-default icon icon-bug', 'Report Issue'
        @button outlet: 'readmeButton', class: 'btn btn-default icon icon-book', 'Open README'

      @div outlet: 'errors'

  initialize: (@pack, @packageManager) ->
    @title.text("#{_.undasherize(_.uncamelcase(@pack.name))}")
    @uninstallButton.hide() if atom.packages.isBundledPackage(@pack.name)

    @type = if @pack.metadata.theme then 'theme' else 'package'
    @startupTime.text("This #{@type} added #{@getStartupTime()}ms to startup time.")

    @description.text(@pack.metadata.description)
    @version.text(@pack.metadata.version)
    @disableButton.hide() if @pack.metadata.theme
    @append(new SettingsPanel(@pack.name, {includeTitle: false}))
    @append(new PackageKeymapView(@pack.name))
    @append(new PackageGrammarsView(@pack.path))
    @append(new PackageSnippetsView(@pack.path))
    @handleButtonEvents()
    @updateEnablement()
    @checkForUpdate()

  handleButtonEvents: ->
    @disableButton.on 'click', =>
      if atom.packages.isPackageDisabled(@pack.name)
        atom.packages.enablePackage(@pack.name)
      else
        atom.packages.disablePackage(@pack.name)
      @updateEnablement()
      false

    @uninstallButton.on 'click', =>
      @uninstallButton.prop('disabled', true)
      @packageManager.uninstall @pack, (error) =>
        if error?
          @errors.append(new ErrorView(error))
          @uninstallButton.prop('disabled', false)
          console.error("Uninstalling #{@type} #{@pack.name} failed", error.stack ? error, error.stderr)
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

  checkForUpdate: ->
    @updateArea.hide()

    @packageManager.getAvailable()
      .then (packages) =>
        for pack in packages when @pack.name is pack.name
          available = pack
        return unless available?

        installedVersion = @pack.metadata.version
        return unless semver.valid(installedVersion)

        availableVersion = available.version
        return unless semver.valid(availableVersion)

        if semver.gt(availableVersion, installedVersion)
          @updateLabel.text ("Version #{availableVersion} is now available!")
          @updateArea.show()

      .catch ->
