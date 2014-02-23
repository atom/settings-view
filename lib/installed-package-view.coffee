path = require 'path'
url = require 'url'

_ = require 'underscore-plus'
fs = require 'fs-plus'
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

      @p outlet: 'packageRepo', class: 'link icon icon-repo repo-link'
      @p outlet: 'description', class: 'text-subtle'
      @p outlet: 'startupTime', class: 'text-subtle icon icon-dashboard'

      @div outlet: 'buttons', class: 'btn-group', =>
        @button outlet: 'disableButton', class: 'btn btn-default icon'
        @button outlet: 'uninstallButton', class: 'btn btn-default icon icon-trashcan', 'Uninstall'
        @button outlet: 'issueButton', class: 'btn btn-default icon icon-bug', 'Report Issue'
        @button outlet: 'readmeButton', class: 'btn btn-default icon icon-book', 'Open README'

      @div outlet: 'errors'

      @div outlet: 'sections'

  initialize: (@pack, @packageManager) ->
    @populate()
    @handleButtonEvents()
    @updateEnablement()
    @checkForUpdate()

  populate: ->
    @title.text("#{_.undasherize(_.uncamelcase(@pack.name))}")
    @uninstallButton.hide() if atom.packages.isBundledPackage(@pack.name)

    @type = if @pack.metadata.theme then 'theme' else 'package'
    @startupTime.text("This #{@type} added #{@getStartupTime()}ms to startup time.")

    if repoUrl = @getRepositoryUrl()
      @packageRepo.text(url.parse(repoUrl).pathname.substring(1)).show()
    else
      @packageRepo.hide()

    @description.text(@pack.metadata.description)
    @version.text(@pack.metadata.version)
    @disableButton.hide() if @pack.metadata.theme

    @sections.empty()
    @sections.append(new SettingsPanel(@pack.name, {includeTitle: false}))
    @sections.append(new PackageKeymapView(@pack.name))
    @sections.append(new PackageGrammarsView(@pack.path))
    @sections.append(new PackageSnippetsView(@pack.path))

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

    @packageRepo.on 'click', =>
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
    {repository} = @pack.metadata
    repoUrl = repository?.url ? repository ? ''
    repoUrl.replace(/\.git$/, '').replace(/\/+$/, '')

  installUpdate: ->
    return if @updateLink.prop('disabled')
    return unless @availableVersion

    @disableButton.prop('disabled', true)
    @uninstallButton.prop('disabled', true)
    @updateLink.prop('disabled', true)
    @updateLink.text('Installing\u2026')

    @packageManager.update @pack, @availableVersion, (error) =>
      @disableButton.prop('disabled', false)
      @uninstallButton.prop('disabled', false)

      if error?
        @updateLink.prop('disabled', false)
        @updateLink.text('Install')
        @errors.append(new ErrorView(error))
      else
        @updateArea.hide()
        if updatedPackage = atom.packages.getLoadedPackage(@pack.name)
          @pack = updatedPackage
          @populate()

  checkForUpdate: ->
    @updateArea.hide()
    @updateLink.on 'click', => @installUpdate()

    @packageManager.getPackage(@pack.name).then (available) =>
      return unless available?
      return unless @packageManager.canUpgrade(@pack, available)

      @availableVersion = available.version
      @updateLabel.text ("Version #{@availableVersion} is now available!")
      @updateArea.show()
