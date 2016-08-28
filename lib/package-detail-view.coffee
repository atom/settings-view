path = require 'path'
url = require 'url'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{shell} = require 'electron'
{ScrollView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'

PackageCard = require './package-card'
PackageGrammarsView = require './package-grammars-view'
PackageKeymapView = require './package-keymap-view'
PackageReadmeView = require './package-readme-view'
PackageSnippetsView = require './package-snippets-view'
SettingsPanel = require './settings-panel'

NORMALIZE_PACKAGE_DATA_README_ERROR = 'ERROR: No README data found!'

module.exports =
class PackageDetailView extends ScrollView

  @content: (pack) ->
    @div tabindex: 0, class: 'package-detail panels-item', =>
      @ol outlet: 'breadcrumbContainer', class: 'native-key-bindings breadcrumb', tabindex: -1, =>
        @li =>
          @a outlet: 'breadcrumb'
        @li class: 'active', =>
          @a outlet: 'title'

      @section class: 'section', =>
        @form class: 'section-container package-detail-view', =>
          @div class: 'container package-container', =>
            @div outlet: 'packageCardParent', class: 'row', =>
              @div outlet: 'loadingMessage', class: 'alert alert-info icon icon-hourglass', "Loading #{pack.name}\u2026"
              @div outlet: 'errorMessage', class: 'alert alert-danger icon icon-hourglass hidden', "Failed to load #{pack.name} - try again later."

          @p outlet: 'packageRepo', class: 'link icon icon-repo repo-link hidden'
          @p outlet: 'startupTime', class: 'text icon icon-dashboard native-key-bindings hidden', tabindex: -1

          @div outlet: 'buttons', class: 'btn-wrap-group hidden', =>
            @button outlet: 'learnMoreButton', class: 'btn btn-default icon icon-link', 'View on Atom.io'
            @button outlet: 'issueButton', class: 'btn btn-default icon icon-bug', 'Report Issue'
            @button outlet: 'changelogButton', class: 'btn btn-default icon icon-squirrel', 'CHANGELOG'
            @button outlet: 'licenseButton', class: 'btn btn-default icon icon-law', 'LICENSE'
            @button outlet: 'openButton', class: 'btn btn-default icon icon-link-external', 'View Code'

          @div outlet: 'errors'

      @div outlet: 'sections'

  initialize: (@package, @snippetsProvider) ->
    super
    @disposables = new CompositeDisposable()

    @packageCard = new PackageCard(@package, onSettingsView: true)
    @loadingMessage.replaceWith(@packageCard)

    @packageRepo.removeClass('hidden')
    @startupTime.removeClass('hidden')
    @buttons.removeClass('hidden')

    @populate()
    @handleButtonEvents()
    @updateFileButtons()
    @subscribeToPackageManager()
    @renderReadme()

  showLoadingMessage: ->
    @loadingMessage.removeClass('hidden')

  hideLoadingMessage: ->
    @loadingMessage.addClass('hidden')

  showErrorMessage: ->
    @errorMessage.removeClass('hidden')

  hideErrorMessage: ->
    @errorMessage.addClass('hidden')

  dispose: ->
    @disposables.dispose()

  beforeShow: (opts = {}) ->
    opts.back ?= 'Install'
    @breadcrumb.text(opts.back).on 'click', =>
      @parents('.settings-view').view()?.showPanel(opts.back)

  populate: ->
    @title.text("#{_.undasherize(_.uncamelcase(@package.name))}")

    @type = if @package.metadata.theme then 'theme' else 'package'

    if repoUrl = @package.repositoryUrl()
      repoName = url.parse(repoUrl).pathname
      @packageRepo.text(repoName.substring(1)).show()
    else
      @packageRepo.hide()

    @updateInstalledState()

  updateInstalledState: ->
    @sections.empty()
    @updateFileButtons()

    if @package.isInstalled()
      @sections.append(new SettingsPanel(@package.name, {includeTitle: false}))
      @sections.append(new PackageKeymapView(@package))

      if @package.path
        @sections.append(new PackageGrammarsView(@package.path))
        @sections.append(new PackageSnippetsView(@package.path, @snippetsProvider))

      @startupTime.html("This #{@type} added <span class='highlight'>#{@getStartupTime()}ms</span> to startup time.")
    else
      @startupTime.hide()
      @openButton.hide()

    @openButton.hide() if atom.packages.isBundledPackage(@package.name)

    @renderReadme()

  renderReadme: ->
    @readme = @package?.metadata?.readme ? @package.readme

    if @readme and @readme.trim() isnt NORMALIZE_PACKAGE_DATA_README_ERROR
      readme = @readme
    else
      readme = null

    if @readmePath and not readme
      readme = fs.readFileSync(@readmePath, encoding: 'utf8')

    readmeView = new PackageReadmeView(readme)
    if @readmeSection
      @readmeSection.replaceWith(readmeView)
    else
      @readmeSection = readmeView
      @sections.append(readmeView)

  subscribeToPackageManager: ->
    @disposables.add @package.on 'installed', =>
      @updateInstalledState()

    @disposables.add @package.on 'uninstalled', =>
      @updateInstalledState()

    @disposables.add @package.on 'theme-updated package-updated', =>
      @updateFileButtons()
      @populate()

  handleButtonEvents: ->
    @packageRepo.on 'click', =>
      if repoUrl = @package.getRepositoryUrl()
        shell.openExternal(repoUrl)
      false

    @issueButton.on 'click', =>
      if repoUrl =  @package.getRepositoryUrl()
        shell.openExternal("#{repoUrl}/issues/new")
      false

    @changelogButton.on 'click', =>
      @openMarkdownFile(@changelogPath) if @changelogPath
      false

    @licenseButton.on 'click', =>
      @openMarkdownFile(@licensePath) if @licensePath
      false

    @openButton.on 'click', =>
      atom.open(pathsToOpen: [@package.path]) if fs.existsSync(@package.path)
      false

    @learnMoreButton.on 'click', =>
      shell.openExternal "https://atom.io/packages/#{@package.name}"
      false

  openMarkdownFile: (path) ->
    if atom.packages.isPackageActive('markdown-preview')
      atom.workspace.open(encodeURI("markdown-preview://#{path}"))
    else
      atom.workspace.open(path)

  updateFileButtons: ->
    @changelogPath = null
    @licensePath = null
    @readmePath = null

    for child in fs.listSync(@package.path)
      switch path.basename(child, path.extname(child)).toLowerCase()
        when 'changelog', 'history' then @changelogPath = child
        when 'license', 'licence' then @licensePath = child
        when 'readme' then @readmePath = child

      break if @readmePath and @changelogPath and @licensePath

    if @changelogPath then @changelogButton.show() else @changelogButton.hide()
    if @licensePath then @licenseButton.show() else @licenseButton.hide()

  getStartupTime: ->
    loadTime = @package.loadTime ? 0
    activateTime = @package.activateTime ? 0
    loadTime + activateTime
