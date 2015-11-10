path = require 'path'
url = require 'url'

_ = require 'underscore-plus'
fs = require 'fs-plus'
shell = require 'shell'
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

  @content: (pack, packageManager) ->
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
              # Packages that need to be fetched will *only* have `name` set
              if pack?.metadata and pack.metadata.owner
                @subview 'packageCard', new PackageCard(pack.metadata, packageManager, onSettingsView: true)
              else
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

  initialize: (@pack, @packageManager, @snippetsProvider) ->
    super
    @disposables = new CompositeDisposable()
    @loadPackage()

  completeInitialzation: ->
    unless @packageCard # Had to load this from the network
      @packageCard = new PackageCard(@pack.metadata, @packageManager, onSettingsView: true)
      @loadingMessage.replaceWith(@packageCard)

    @packageRepo.removeClass('hidden')
    @startupTime.removeClass('hidden')
    @buttons.removeClass('hidden')
    @activateConfig()
    @populate()
    @handleButtonEvents()
    @updateFileButtons()
    @subscribeToPackageManager()
    @renderReadme()

  loadPackage: ->
    if loadedPackage = atom.packages.getLoadedPackage(@pack.name)
      @pack = loadedPackage
      @completeInitialzation()
    else
      # If the package metadata in `@pack` isn't complete, hit the network.
      unless @pack.metadata? and @pack.metadata.owner
        @fetchPackage()
      else
        @completeInitialzation()

  fetchPackage: ->
    @showLoadingMessage()
    @packageManager.getClient().package @pack.name, (err, packageData) =>
      if err or not(packageData?.name?)
        @hideLoadingMessage()
        @showErrorMessage()
      else
        @pack = packageData
        # TODO: this should match Package.loadMetadata from core, but this is
        # an acceptable hacky workaround
        @pack.metadata = _.extend(@pack.metadata ? {}, @pack)
        @completeInitialzation()

  showLoadingMessage: ->
    @loadingMessage.removeClass('hidden')

  hideLoadingMessage: ->
    @loadingMessage.addClass('hidden')

  showErrorMessage: ->
    @errorMessage.removeClass('hidden')

  hideErrorMessage: ->
    @errorMessage.addClass('hidden')

  activateConfig: ->
    # Package.activateConfig() is part of the Private package API and should not be used outside of core.
    if atom.packages.isPackageLoaded(@pack.name) and not atom.packages.isPackageActive(@pack.name)
      @pack.activateConfig()

  dispose: ->
    @disposables.dispose()

  beforeShow: (opts) ->
    opts.back ?= 'Install'
    @breadcrumb.text(opts.back).on 'click', =>
      @parents('.settings-view').view()?.showPanel(opts.back)

  populate: ->
    @title.text("#{_.undasherize(_.uncamelcase(@pack.name))}")

    @type = if @pack.metadata.theme then 'theme' else 'package'

    if repoUrl = @packageManager.getRepositoryUrl(@pack)
      repoName = url.parse(repoUrl).pathname
      @packageRepo.text(repoName.substring(1)).show()
    else
      @packageRepo.hide()

    @updateInstalledState()

  updateInstalledState: ->
    @sections.empty()
    @updateFileButtons()
    @activateConfig()

    if @isInstalled()
      @sections.append(new SettingsPanel(@pack.name, {includeTitle: false}))
      @sections.append(new PackageKeymapView(@pack))

      if @pack.path
        @sections.append(new PackageGrammarsView(@pack.path))
        @sections.append(new PackageSnippetsView(@pack.path, @snippetsProvider))

      @startupTime.html("This #{@type} added <span class='highlight'>#{@getStartupTime()}ms</span> to startup time.")
    else
      @startupTime.hide()
      @openButton.hide()

    @openButton.hide() if atom.packages.isBundledPackage(@pack.name)

    @renderReadme()

  renderReadme: ->
    if @pack.metadata.readme and @pack.metadata.readme.trim() isnt NORMALIZE_PACKAGE_DATA_README_ERROR
      readme = @pack.metadata.readme
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
    @disposables.add @packageManager.on 'theme-installed package-installed', ({pack}) =>
      return unless @pack.name is pack.name

      @loadPackage()
      @updateInstalledState()

    @disposables.add @packageManager.on 'theme-uninstalled package-uninstalled', ({pack}) =>
      @updateInstalledState() if @pack.name is pack.name

    @disposables.add @packageManager.on 'theme-updated package-updated', ({pack}) =>
      return unless @pack.name is pack.name

      @loadPackage()
      @updateFileButtons()
      @populate()

  handleButtonEvents: ->
    @packageRepo.on 'click', =>
      if repoUrl = @packageManager.getRepositoryUrl(@pack)
        shell.openExternal(repoUrl)
      false

    @issueButton.on 'click', =>
      if repoUrl = @packageManager.getRepositoryUrl(@pack)
        shell.openExternal("#{repoUrl}/issues/new")
      false

    @changelogButton.on 'click', =>
      @openMarkdownFile(@changelogPath) if @changelogPath
      false

    @licenseButton.on 'click', =>
      @openMarkdownFile(@licensePath) if @licensePath
      false

    @openButton.on 'click', =>
      atom.open(pathsToOpen: [@pack.path]) if fs.existsSync(@pack.path)
      false

    @learnMoreButton.on 'click', =>
      shell.openExternal "https://atom.io/packages/#{@pack.name}"
      false

  openMarkdownFile: (path) ->
    if atom.packages.isPackageActive('markdown-preview')
      atom.workspace.open("#{encodeURI("markdown-preview://#{path}")}")
    else
      atom.workspace.open(path)

  updateFileButtons: ->
    @changelogPath = null
    @licensePath = null
    @readmePath = null

    for child in fs.listSync(@pack.path)
      switch path.basename(child, path.extname(child)).toLowerCase()
        when 'changelog', 'history' then @changelogPath = child
        when 'license', 'licence' then @licensePath = child
        when 'readme' then @readmePath = child

      break if @readmePath and @changelogPath and @licensePath

    if @changelogPath then @changelogButton.show() else @changelogButton.hide()
    if @licensePath then @licenseButton.show() else @licenseButton.hide()

  getStartupTime: ->
    loadTime = @pack.loadTime ? 0
    activateTime = @pack.activateTime ? 0
    loadTime + activateTime

  # Even though the title of this view is hilariously "PackageDetailView",
  # the package might not be installed.
  isInstalled: ->
    atom.packages.isPackageLoaded(@pack.name) and not atom.packages.isPackageDisabled(@pack.name)
