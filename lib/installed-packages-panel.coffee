path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{$, $$, View, TextEditorView} = require 'atom'

AvailablePackageView = require './available-package-view'
PackageCardView = require './package-card-view'
ErrorView = require './error-view'
PackageManager = require './package-manager'
PackageUpdateView = require './package-update-view'

module.exports =
class InstalledPackagesPanel extends View
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

      @div class: 'section installed-packages', =>
        @div class: 'section-heading icon icon-package', 'Installed Packages'
        @div outlet: 'installedPackages', class: 'container package-container'

      @div class: 'section core-packages', =>
        @div class: 'section-heading icon icon-package', 'Core Packages'
        @div outlet: 'corePackages', class: 'container package-container'

      @div class: 'section dev-packages', =>
        @div class: 'section-heading icon icon-package', 'Development Packages'
        @div outlet: 'devPackages', class: 'container package-container'


  initialize: (@packageManager) ->
    @noUpdatesMessage.hide()

    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @searchErrors.append(new ErrorView(@packageManager, error))

    @subscribe @packageManager, 'package-update-failed theme-update-failed', (pack, error) =>
      @updateErrors.append(new ErrorView(@packageManager, error))

    @updateAllButton.hide()
    @updateAllButton.on 'click', =>
      @updateAllButton.prop('disabled', true)
      for updateView in @updatesContainer.find('.available-package-view')
        $(updateView).view()?.upgrade?()

    @loadPackages()

    @checkForUpdates()

  loadPackages: ->
    @packageManager.getInstalled()
      .then (packages) =>
        packages = @filterPackages(packages)

        # @loadingMessage.hide()
        # TODO show empty mesage per section
        # @emptyMessage.show() if packages.length is 0
        @addPackageViews(@installedPackages, packages.user)
        @addPackageViews(@corePackages, packages.core)
        @addPackageViews(@devPackages, packages.dev)
      .catch (error) =>
        @loadingMessage.hide()
        # TODO errors by section
        @featuredErrors.append(new ErrorView(@packageManager, error))


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
        @searchErrors.append(new ErrorView(@packageManager, error))

  addPackageViews: (container, packages) ->
    console.log "adding packages"
    console.log container
    console.log packages
    container.empty()

    for pack, index in packages
      console.log pack
      if index % 3 is 0
        packageRow = $$ -> @div class: 'row'
        container.append(packageRow)
      packageRow.append(new AvailablePackageView(pack, @packageManager))

  addUpdateViews: ->
    @updateAllButton.show() if @availableUpdates.length > 0
    @checkingMessage.hide()
    @updatesContainer.empty()
    @noUpdatesMessage.show() if @availableUpdates.length is 0

    for pack, index in @availableUpdates
      if index % 3 is 0
        packageRow = $$ -> @div class: 'row'
        @updatesContainer.append(packageRow)
      packageRow.append(new PackageUpdateView(pack, @packageManager))

  filterPackages: (packages) ->
    packages.dev = packages.dev.filter ({theme}) -> not theme
    packages.user = packages.user.filter ({theme}) -> not theme
    packages.core = packages.core.filter ({theme}) -> not theme
    packages
  # Check for updates and display them
  checkForUpdates: ->
    @checkingMessage.show()

    @packageManager.getOutdated()
      .then (@availableUpdates) =>
        @addUpdateViews()
      .catch (error) =>
        @checkingMessage.hide()
        @updateErrors.append(new ErrorView(@packageManager, error))
