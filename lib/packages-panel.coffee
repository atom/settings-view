path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{$$, View} = require 'atom'

AvailablePackageView = require './available-package-view'
ErrorView = require './error-view'
PackageManager = require './package-manager'
PackageUpdateView = require './package-update-view'
SettingEditorView = require './setting-editor-view'

module.exports =
class PackagesPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-heading icon icon-squirrel', =>
          @span 'Available Updates'
          @button outlet: 'updateAllButton', class: 'pull-right btn btn-primary', 'Update All'

        @div outlet: 'updateErrors'
        @div outlet: 'checkingMessage', class: 'alert alert-info featured-message icon icon-hourglass', 'Checking for updates\u2026'
        @div outlet: 'noUpdatesMessage', class: 'alert alert-info featured-message icon icon-heart', 'All of your installed packages are up to date!'
        @div outlet: 'updatesContainer', class: 'container package-container'

      @div class: 'section packages', =>
        @div class: 'section-heading icon icon-cloud-download', 'Install Packages'

        @div class: 'text padded native-key-bindings', tabindex: -1, =>
          @span class: 'icon icon-question'
          @span 'Packages are published to  '
          @a class: 'link', outlet: "openAtomIo", "atom.io"
          @span " and are installed to #{path.join(fs.getHomeDirectory(), '.atom', 'packages')}"

        @div class: 'editor-container padded', =>
          @subview 'searchEditorView', new SettingEditorView()

        @div outlet: 'searchErrors'
        @div outlet: 'searchMessage', class: 'alert alert-info search-message icon icon-search'
        @div outlet: 'resultsContainer', class: 'container package-container'

      @div class: 'section packages', =>
        @div class: 'section-heading icon icon-star', 'Featured Packages'
        @div outlet: 'featuredErrors'
        @div outlet: 'loadingMessage', class: 'alert alert-info featured-message icon icon-hourglass', 'Loading featured packages\u2026'
        @div outlet: 'emptyMessage', class: 'alert alert-info featured-message icon icon-heart', 'You have every featured package installed already!'
        @div outlet: 'featuredContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    @openAtomIo.on 'click', =>
      require('shell').openExternal('https://atom.io/packages')
      false

    @noUpdatesMessage.hide()
    @searchMessage.hide()
    @emptyMessage.hide()

    @searchEditorView.setPlaceholderText('Search packages')
    @searchEditorView.on 'core:confirm', =>
      if query = @searchEditorView.getText().trim()
        @search(query)

    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @searchErrors.append(new ErrorView(error))

    @subscribe @packageManager, 'package-update-failed theme-update-failed', (pack, error) =>
      @updateErrors.append(new ErrorView(error))

    @updateAllButton.prop('disabled', true)
    @updateAllButton.on 'click', =>
      @updateAllButton.prop('disabled', true)
      for pack in @availableUpdates
        @packageManager.update(pack, pack.latestVersion)

    @loadFeaturedPackages()
    @checkForUpdates()

  focus: ->
    @searchEditorView.focus()

  search: (query) ->
    if @resultsContainer.children().length is 0
      @searchMessage.text("Searching for \u201C#{query}\u201D\u2026").show()

    @packageManager.search(query, {packages: true})
      .then (packages=[]) =>
        if packages.length is 0
          @searchMessage.text("No package results for \u201C#{query}\u201D").show()
        else
          @searchMessage.hide()
        @addPackageViews(@resultsContainer, packages)
      .catch (error) =>
        @searchMessage.hide()
        @searchErrors.append(new ErrorView(error))

  addPackageViews: (container, packages) ->
    container.empty()

    for pack, index in packages
      if index % 3 is 0
        packageRow = $$ -> @div class: 'row'
        container.append(packageRow)
      packageRow.append(new AvailablePackageView(pack, @packageManager))

  addUpdateViews: ->
    @updateAllButton.prop('disabled', @availableUpdates.length is 0)
    @checkingMessage.hide()
    @updatesContainer.empty()
    @noUpdatesMessage.show() if @availableUpdates.length is 0

    for pack, index in @availableUpdates
      if index % 3 is 0
        packageRow = $$ -> @div class: 'row'
        @updatesContainer.append(packageRow)
      packageRow.append(new PackageUpdateView(pack, @packageManager))

  filterPackages: (packages) ->
    packages.filter ({theme}) -> not theme

  # Load and display the featured packages that are available to install.
  loadFeaturedPackages: ->
    @loadingMessage.show()

    @packageManager.getFeatured()
      .then (packages) =>
        packages = @filterPackages(packages)
        @loadingMessage.hide()
        @emptyMessage.show() if packages.length is 0
        @addPackageViews(@featuredContainer, packages)
      .catch (error) =>
        @loadingMessage.hide()
        @featuredErrors.append(new ErrorView(error))

  # Check for updates and display them
  checkForUpdates: ->
    @checkingMessage.show()

    @packageManager.getOutdated()
      .then (@availableUpdates) =>
        @addUpdateViews()
      .catch (error) =>
        @checkingMessage.hide()
        @updateErrors.append(new ErrorView(error))
