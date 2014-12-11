path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{$, $$, View, TextEditorView} = require 'atom'

AvailablePackageView = require './available-package-view'
ErrorView = require './error-view'
PackageManager = require './package-manager'

module.exports =
class InstallPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-container', =>
          @h1 class: 'section-heading icon icon-cloud-download', 'Install Packages'

          @div class: 'text native-key-bindings', tabindex: -1, =>
            @span class: 'icon icon-question'
            @span 'Packages are published to  '
            @a class: 'link', outlet: "openAtomIo", "atom.io"
            @span " and are installed to #{path.join(fs.getHomeDirectory(), '.atom', 'packages')}"

          @div class: 'search-container clearfix', =>
            @div class: 'editor-container', =>
              @subview 'searchEditorView', new TextEditorView(mini: true)
            @div class: 'btn-group', =>
              @button outlet: 'searchPackagesButton', type: 'button', class: 'btn btn-default selected', 'Packages'
              @button outlet: 'searchThemesButton', type: 'button', class: 'btn btn-default', 'Themes'

          @div outlet: 'searchErrors'
          @div outlet: 'searchMessage', class: 'alert alert-info search-message icon icon-search'
          @div outlet: 'resultsContainer', class: 'container package-container'

      @div class: 'section packages', =>
        @div class: 'section-container', =>
          @div outlet: 'featuredHeading', class: 'section-heading icon icon-star', 'Featured Packages'
          @div outlet: 'featuredErrors'
          @div outlet: 'loadingMessage', class: 'alert alert-info featured-message icon icon-hourglass', 'Loading featured packages\u2026'
          @div outlet: 'featuredContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    @openAtomIo.on 'click', =>
      require('shell').openExternal('https://atom.io/packages')
      false

    @searchMessage.hide()

    @searchEditorView.setPlaceholderText('Search packages')
    @searchType = 'packages'
    @handleSearchEvents()

    @loadFeaturedPackages()

  focus: ->
    @searchEditorView.focus()

  handleSearchEvents: ->
    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @searchErrors.append(new ErrorView(@packageManager, error))

    @searchEditorView.on 'core:confirm', =>
      @performSearch()

    @searchPackagesButton.on 'click', =>
      unless @searchPackagesButton.hasClass('selected')
        @searchType = 'packages'
        @searchPackagesButton.addClass('selected')
        @searchThemesButton.removeClass('selected')
        @searchEditorView.setPlaceholderText('Search packages')
        @loadFeaturedPackages()
        @performSearch()


    @searchThemesButton.on 'click', =>
      unless @searchThemesButton.hasClass('selected')
        @searchType = 'themes'
        @searchThemesButton.addClass('selected')
        @searchPackagesButton.removeClass('selected')
        @searchEditorView.setPlaceholderText('Search themes')
        @loadFeaturedPackages(true)
        @performSearch()

  performSearch: ->
    if query = @searchEditorView.getText().trim()
      @search(query)

  search: (query) ->
    @resultsContainer.empty()
    @searchMessage.text("Searching #{@searchType} for \u201C#{query}\u201D\u2026").show()

    opts = {}
    opts[@searchType] = true
    @packageManager.search(query, opts)
      .then (packages=[]) =>
        if packages.length is 0
          @searchMessage.text("No #{@searchType.replace(/s$/, '')} results for \u201C#{query}\u201D").show()
        else
          @searchMessage.hide()
        @addPackageViews(@resultsContainer, packages)
      .catch (error) =>
        @searchMessage.hide()
        @searchErrors.append(new ErrorView(@packageManager, error))

  addPackageViews: (container, packages) ->
    container.empty()

    for pack, index in packages
      packageRow = $$ -> @div class: 'row'
      container.append(packageRow)
      packageRow.append(new AvailablePackageView(pack, @packageManager))

  filterPackages: (packages, themes) ->
    packages.filter ({theme}) =>
      if themes
        theme
      else
        not theme

  # Load and display the featured packages that are available to install.
  loadFeaturedPackages: (loadThemes) ->
    loadThemes ?= false
    @loadingMessage.show()

    @packageManager.getFeatured()
      .then (packages) =>
        packages = @filterPackages(packages, loadThemes)
        @loadingMessage.hide()
        @addPackageViews(@featuredContainer, packages)
        if loadThemes
          @featuredHeading.text 'Featured Themes'
        else
          @featuredHeading.text 'Featured Packages'

      .catch (error) =>
        @loadingMessage.hide()
        @featuredErrors.append(new ErrorView(@packageManager, error))
