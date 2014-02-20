_ = require 'underscore-plus'
{$$, EditorView, View} = require 'atom'

ErrorView = require './error-view'
PackageManager = require './package-manager'
AvailablePackageView = require './available-package-view'

module.exports =
class PackagesPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-heading theme-heading icon icon-cloud-download', 'Install Packages'

        @div class: 'editor-container padded', =>
          @subview 'searchEditorView', new EditorView(mini: true)

        @div outlet: 'errors'

        @div outlet: 'results', =>
          @div outlet: 'searchMessage', class: 'icon icon-search text'
          @div outlet: 'resultsContainer', class: 'container package-container'

        @div outlet: 'featured', =>
          @div class: 'icon icon-star text', 'Featured Packages'
          @div outlet: 'loadingMessage', class: 'padded text icon icon-hourglass', 'Loading featured packages\u2026'
          @div outlet: 'emptyMessage', class: 'padded text icon icon-heart', 'You have every featured package installed already!'
          @div outlet: 'featuredContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    @results.hide()
    @emptyMessage.hide()

    @searchEditorView.setPlaceholderText('Search packages')
    @searchEditorView.on 'core:confirm', =>
      @search(@searchEditorView.getText().trim())

    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @errors.append(new ErrorView(error))

    @loadFeaturedPackages()

  focus: ->
    @searchEditorView.focus()

  search: (query) ->
    @results.show()
    @searchMessage.text("Searching for '#{query}'\u2026").show()

    @packageManager.search(query)
      .then (packages=[]) =>
        packages = @filterInstalledPackages(packages)
        @searchMessage.text("Search results for '#{query}' (#{packages.length})")
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
