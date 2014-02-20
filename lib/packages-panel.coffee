path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{$$, EditorView, View} = require 'atom'

ErrorView = require './error-view'
PackageManager = require './package-manager'
AvailablePackageView = require './available-package-view'

module.exports =
class PackagesPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-heading icon icon-cloud-download', 'Install Packages'

        @div class: 'text padded', =>
          @span class: 'icon icon-question'
          @span 'Packages are hosted on  '
          @a class: 'link', outlet: "openAtomIo", "atom.io"
          @span " and are installed to #{path.join(fs.getHomeDirectory(), '.atom', 'packages')}"

        @div outlet: 'errors'

        @div class: 'editor-container padded', =>
          @subview 'searchEditorView', new EditorView(mini: true)

        @div outlet: 'results', =>
          @div outlet: 'searchMessage', class: 'alert alert-info search-message icon icon-search'
          @div outlet: 'resultsContainer', class: 'container package-container'

      @div class: 'section packages', =>
        @div class: 'section-heading icon icon-star', 'Featured Packages'
        @div outlet: 'loadingMessage', class: 'alert alert-info featured-message icon icon-hourglass', 'Loading featured packages\u2026'
        @div outlet: 'emptyMessage', class: 'alert alert-info featured-message icon icon-heart', 'You have every featured package installed already!'
        @div outlet: 'featuredContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    @openAtomIo.on 'click', =>
      require('shell').openExternal('https://atom.io/packages')
      false

    @searchMessage.hide()
    @emptyMessage.hide()

    @searchEditorView.setPlaceholderText('Search packages')
    @searchEditorView.on 'core:confirm', =>
      if query = @searchEditorView.getText().trim()
        @search(query)

    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @errors.append(new ErrorView(error))

    @loadFeaturedPackages()

  focus: ->
    @searchEditorView.focus()

  search: (query) ->
    if @resultsContainer.children().length is 0
      @searchMessage.text("Searching for '#{query}'\u2026").show()

    @packageManager.search(query)
      .then (packages=[]) =>
        packages = @filterInstalledPackages(packages)
        if packages.length is 0
          @searchMessage.text("No package results for '#{query}'").show()
        else
          @searchMessage.hide()
        @results.show()
        @addPackageViews(@resultsContainer, packages)
      .catch (error) =>
        @errors.append(new ErrorView(error))

  addPackageViews: (container, packages) ->
    container.empty()

    for pack, index in packages
      if index % 4 is 0
        packageRow = $$ -> @div class: 'row'
        container.append(packageRow)
      packageRow.append(new AvailablePackageView(pack, @packageManager))

  filterInstalledPackages: (packages) ->
    installedPackages = atom.packages.getAvailablePackageNames()
    packages.filter ({name, theme}) ->
      not theme and not (name in installedPackages)

  # Load and display the featured packages that are available to install.
  loadFeaturedPackages: ->
    @loadingMessage.show()

    @packageManager.getFeatured()
      .then (packages) =>
        packages = @filterInstalledPackages(packages)
        @loadingMessage.hide()
        @emptyMessage.show() if packages.length is 0
        @addPackageViews(@featuredContainer, packages)
      .catch (error) =>
        @loadingMessage.hide()
        @errors.append(new ErrorView(error))
