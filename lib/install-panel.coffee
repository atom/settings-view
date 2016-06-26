path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{$, $$, TextEditorView, ScrollView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'

PackageCard = require './package-card'
Client = require './atom-io-client'
ErrorView = require './error-view'
PackageManager = require './package-manager'

PackageNameRegex = /config\/install\/(package|theme):([a-z0-9-_]+)/i
hostedGitInfo = require 'hosted-git-info'

module.exports =
class InstallPanel extends ScrollView
  @content: ->
    @div class: 'panels-item', =>
      @div class: 'section packages', =>
        @div class: 'section-container', =>
          @h1 outlet: 'installHeading', class: 'section-heading icon icon-cloud-download', 'Install Packages'

          @div class: 'text native-key-bindings', tabindex: -1, =>
            @span class: 'icon icon-question'
            @span outlet: 'publishedToText', 'Packages are published to '
            @a class: 'link', outlet: "openAtomIo", "atom.io"
            @span " and are installed to #{path.join(process.env.ATOM_HOME, 'packages')}"

          @div class: 'search-container clearfix', =>
            @div class: 'editor-container', =>
              @subview 'searchEditorView', new TextEditorView(mini: true)
            @div class: 'btn-group', =>
              @button outlet: 'searchPackagesButton', class: 'btn btn-default selected', 'Packages'
              @button outlet: 'searchThemesButton', class: 'btn btn-default', 'Themes'

          @div outlet: 'searchErrors'
          @div outlet: 'searchMessage', class: 'alert alert-info search-message icon icon-search'
          @div outlet: 'resultsContainer', class: 'container package-container'

      @div class: 'section packages', =>
        @div class: 'section-container', =>
          @div outlet: 'featuredHeading', class: 'section-heading icon icon-star'
          @div outlet: 'featuredErrors'
          @div outlet: 'loadingMessage', class: 'alert alert-info icon icon-hourglass'
          @div outlet: 'featuredContainer', class: 'container package-container'

      @div outlet: 'starredPackagesSection', class: 'section packages', =>
        @div class: 'section-container', =>
          @div outlet: 'starreedHeading', class: 'section-heading icon icon-star', 'Starred Packages'
          @div outlet: 'starreedErrors'
          @div outlet: 'loadingStarredMessage', class: 'alert alert-info icon icon-hourglass'
          @div outlet: 'starreedContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    super
    @disposables = new CompositeDisposable()
    client = $('.settings-view').view()?.client
    @client = @packageManager.getClient()
    @atomIoURL = 'https://atom.io/packages'
    @openAtomIo.on 'click', =>
      require('electron').shell.openExternal(@atomIoURL)
      false

    @searchMessage.hide()

    @searchEditorView.getModel().setPlaceholderText('Search packages')
    @searchType = 'packages'
    @handleSearchEvents()

    if @showStarredPackages()
      @loadStarredPackages()
    else
      atom.config.observe 'settings-view.enableStarredPackages', (enabled) =>
        if enabled
          @loadStarredPackages()

      @starredPackagesSection.hide()

    @loadFeaturedPackages()

  dispose: ->
    @disposables.dispose()

  focus: ->
    @searchEditorView.focus()

  showStarredPackages: ->
    @starredPackages ?= atom.config.get('settings-view.enableStarredPackages')

  handleSearchEvents: ->
    @disposables.add @packageManager.on 'package-install-failed', ({pack, error}) =>
      @searchErrors.append(new ErrorView(@packageManager, error))

    @disposables.add @packageManager.on 'package-installed theme-installed', ({pack}) =>
      gitUrlInfo = @currentGitPackageCard?.pack?.gitUrlInfo
      if gitUrlInfo? and gitUrlInfo is pack.gitUrlInfo
        @updateGitPackageCard(pack)

    @disposables.add atom.commands.add @searchEditorView.element, 'core:confirm', =>
      @performSearch()

    @searchPackagesButton.on 'click', =>
      @setSearchType('package') unless @searchPackagesButton.hasClass('selected')
      @performSearch()

    @searchThemesButton.on 'click', =>
      @setSearchType('theme') unless @searchThemesButton.hasClass('selected')
      @performSearch()

  setSearchType: (searchType) ->
    if searchType is 'theme'
      @searchType = 'themes'
      @searchThemesButton.addClass('selected')
      @searchPackagesButton.removeClass('selected')
      @searchEditorView.getModel().setPlaceholderText('Search themes')
      @publishedToText.text('Themes are published to ')
      @atomIoURL = 'https://atom.io/themes'
      @loadFeaturedPackages(true)
    else if searchType is 'package'
      @searchType = 'packages'
      @searchPackagesButton.addClass('selected')
      @searchThemesButton.removeClass('selected')
      @searchEditorView.getModel().setPlaceholderText('Search packages')
      @publishedToText.text('Packages are published to ')
      @atomIoURL = 'https://atom.io/packages'
      @loadFeaturedPackages()

  beforeShow: (options) ->
    return unless options?.uri?
    query = @extractQueryFromURI(options.uri)
    if query?
      {searchType, packageName} = query
      @setSearchType(searchType)
      @searchEditorView.setText(packageName)
      @performSearch()

  extractQueryFromURI: (uri) ->
    matches = PackageNameRegex.exec(uri)
    if matches?
      [__, searchType, packageName] = matches
      {searchType, packageName}
    else
      null

  performSearch: ->
    query = @searchEditorView.getText().trim()

    if query and query isnt ''
      @performSearchForQuery(query)
    else
      @resultsContainer.empty()

  performSearchForQuery: (query) ->
    if gitUrlInfo = hostedGitInfo.fromUrl(query)
      type = gitUrlInfo.default
      if type is 'sshurl' or type is 'https' or type is 'shortcut'
        @showGitInstallPackageCard(name: query, gitUrlInfo: gitUrlInfo)
    else
      @search(query)

  showGitInstallPackageCard: (pack) ->
    @currentGitPackageCard?.dispose()
    @currentGitPackageCard = @getPackageCardView(pack)
    @currentGitPackageCard.displayGitPackageInstallInformation()
    @replaceCurrentGitPackageCardView()

  updateGitPackageCard: (pack) ->
    @currentGitPackageCard.dispose()
    @currentGitPackageCard = @getPackageCardView(pack)
    @replaceCurrentGitPackageCardView()

  replaceCurrentGitPackageCardView: ->
    @resultsContainer.empty()
    @addPackageCardView(@resultsContainer, @currentGitPackageCard)

  search: (query) ->
    @resultsContainer.empty()
    @searchMessage.text("Searching #{@searchType} for \u201C#{query}\u201D\u2026").show()

    opts = {}
    opts[@searchType] = true
    opts['sortBy'] = "downloads"

    @packageManager.search(query, opts)
      .then (packages=[]) =>
        @resultsContainer.empty()
        packages
      .then (packages=[]) =>
        @searchMessage.hide()
        @showNoResultMessage if packages.length is 0
        packages
      .then (packages=[]) =>
        @highlightExactMatch(@resultsContainer, query, packages)
      .then (packages=[]) =>
        @addPackageViews(@resultsContainer, packages)
      .catch (error) =>
        @searchMessage.hide()
        @searchErrors.append(new ErrorView(@packageManager, error))

  showNoResultMessage: ->
    @searchMessage.text("No #{@searchType.replace(/s$/, '')} results for \u201C#{query}\u201D").show()

  highlightExactMatch: (container, query, packages) ->
    exactMatch = _.filter(packages, (pkg) ->
      pkg.name is query)[0]

    if exactMatch
      packageCard = @getPackageCardView(exactMatch)
      @addPackageCardView(container, packageCard)
      packages.splice(packages.indexOf(exactMatch), 1)

    packages

  addPackageViews: (container, packages) ->
    for pack, index in packages
      packageCard = @getPackageCardView(pack)
      @addPackageCardView(container, packageCard)

  addPackageCardView: (container, packageCard) ->
    packageRow = $$ -> @div class: 'row'
    container.append(packageRow)
    packageRow.append(packageCard)

  getPackageCardView: (pack) ->
    new PackageCard(pack, @packageManager, {back: 'Install', stats: {downloads: true, stars: @showStarredPackages()}})

  filterPackages: (packages, themes) ->
    packages.filter ({theme}) ->
      if themes
        theme
      else
        not theme

  # Load starred packages
  loadStarredPackages: ->
    @starredPackagesSection.show()
    @packageManager.getStarred()
      .then (packages) =>
        @loadingStarredMessage.hide()
        packages
      .then (packages) =>
        @addPackageViews(@starreedContainer, packages)
      .catch (error) =>
        @starreedErrors.append(new ErrorView(@packageManager, error))

  # Load and display the featured packages that are available to install.
  loadFeaturedPackages: (loadThemes) ->
    loadThemes ?= false
    @featuredContainer.empty()

    if loadThemes
      @installHeading.text 'Install Themes'
      @featuredHeading.text 'Featured Themes'
      @loadingMessage.text('Loading featured themes\u2026')
    else
      @installHeading.text 'Install Packages'
      @featuredHeading.text 'Featured Packages'
      @loadingMessage.text('Loading featured packages\u2026')

    @loadingMessage.show()

    handle = (error) =>
      @loadingMessage.hide()
      @featuredErrors.append(new ErrorView(@packageManager, error))

    if loadThemes
      @client.featuredThemes (error, themes) =>
        if error
          handle(error)
        else
          @loadingMessage.hide()
          @featuredHeading.text 'Featured Themes'
          @addPackageViews(@featuredContainer, themes)

    else
      @client.featuredPackages (error, packages) =>
        if error
          handle(error)
        else
          @loadingMessage.hide()
          @featuredHeading.text 'Featured Packages'
          @addPackageViews(@featuredContainer, packages)
