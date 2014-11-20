path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
{$, $$, View, TextEditorView} = require 'atom'
fuzzaldrin = require 'fuzzaldrin'

AvailablePackageView = require './available-package-view'
ErrorView = require './error-view'
PackageManager = require './package-manager'

module.exports =
class InstalledPackagesPanel extends View
  @content: ->
    @div =>
      @h1 class: 'installed-packages-title', =>
        @text 'Installed Packages'
        @span outlet: 'totalPackages', ' (…)'
      @div class: 'editor-container settings-filter', =>
        @subview 'filterEditor', new TextEditorView(mini: true, placeholderText: 'Filter packages by name')

      @div class: 'section installed-packages', =>
        @h2 class: 'section-heading icon icon-package', =>
          @text 'Community Packages'
          @span outlet: 'communityCount', ' (…)'
        @div outlet: 'installedPackages', class: 'container package-container'

      @div class: 'section core-packages', =>
        @h2 class: 'section-heading icon icon-package', =>
          @text 'Core Packages'
          @span outlet: 'coreCount', ' (…)'
        @div outlet: 'corePackages', class: 'container package-container'

      @div class: 'section dev-packages', =>
        @h2 class: 'section-heading icon icon-package', =>
          @text 'Development Packages'
          @span outlet: 'devCount', ' (…)'
        @div outlet: 'devPackages', class: 'container package-container'


  initialize: (@packageManager) ->
    @packageViews = []

    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @searchErrors.append(new ErrorView(@packageManager, error))

    @subscribe @packageManager, 'package-update-failed theme-update-failed', (pack, error) =>
      @updateErrors.append(new ErrorView(@packageManager, error))

    @filterEditor.getEditor().on 'contents-modified', =>
      @matchPackages()

    @loadPackages()

  loadPackages: ->
    @packageViews = []
    @packageManager.getInstalled()
      .then (packages) =>
        @packages = @filterPackages(packages)

        # @loadingMessage.hide()
        # TODO show empty mesage per section
        # @emptyMessage.show() if packages.length is 0
        @totalPackages.text " (#{@packages.user.length + @packages.core.length + @packages.dev.length})"

        _.each @addPackageViews(@installedPackages, @packages.user), (v) => @packageViews.push(v)
        @communityCount.text " (#{@packages.user.length})"
        _.each @addPackageViews(@corePackages, @packages.core), (v) => @packageViews.push(v)
        @coreCount.text " (#{@packages.core.length})"
        _.each @addPackageViews(@devPackages, @packages.dev), (v) => @packageViews.push(v)
        @devCount.text " (#{@packages.dev.length})"
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
    container.empty()
    packageViews = []
    for pack, index in packages
      if index % 3 is 0
        packageRow = $$ -> @div class: 'row'
        container.append(packageRow)
        packView = new AvailablePackageView(pack, @packageManager)
        packView.widen()
      packageViews.push(packView) # used for search filterin'
      packageRow.append(packView)
    packageViews

  filterPackageListByText: (text) ->
    active = fuzzaldrin.filter(@packageViews, text, key: 'name')
    _.each @packageViews, (view) ->
      view.hide()
    _.each active, (view) ->
      view.show()

  updateCounts: ->
    console.log "TODO"

  # TODO rename this and the below
  matchPackages: ->
    filterText = @filterEditor.getEditor().getText()
    if filterText != ''
      @filterPackageListByText(filterText)
    else
      @find('.installed-package-view').show()

    @updateCounts()


  filterPackages: (packages) ->
    filterText = @filterEditor.getEditor().getText()

    packages.dev = packages.dev.filter ({theme}) -> not theme
    packages.user = packages.user.filter ({theme}) -> not theme
    packages.core = packages.core.filter ({theme}) -> not theme

    packages
