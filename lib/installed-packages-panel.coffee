_ = require 'underscore-plus'
{$$, TextEditorView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
fuzzaldrin = require 'fuzzaldrin'

CollapsibleSectionPanel = require './collapsible-section-panel'
PackageCard = require './package-card'
ErrorView = require './error-view'

List = require './list'
ListView = require './list-view'
{packageComparatorAscending} = require './utils'

module.exports =
class InstalledPackagesPanel extends CollapsibleSectionPanel
  @content: ->
    @div class: 'panels-item', =>
      @section class: 'section', =>
        @div class: 'section-container', =>
          @div class: 'section-heading icon icon-package', =>
            @text 'Installed Packages'
            @span outlet: 'totalPackages', class: 'section-heading-count badge badge-flexible', '…'
          @div class: 'editor-container', =>
            @subview 'filterEditor', new TextEditorView(mini: true, placeholderText: 'Filter packages by name')

          @div outlet: 'updateErrors'

          @section outlet: 'deprecatedSection', class: 'sub-section deprecated-packages', =>
            @h3 outlet: 'deprecatedPackagesHeader', class: 'sub-section-heading icon icon-package', =>
              @text 'Deprecated Packages'
              @span outlet: 'deprecatedCount', class: 'section-heading-count badge badge-flexible', '…'
            @p 'Atom does not load deprecated packages. These packages may have updates available.'
            @div outlet: 'deprecatedPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section installed-packages', =>
            @h3 outlet: 'userPackagesHeader', class: 'sub-section-heading icon icon-package', =>
              @text 'Community Packages'
              @span outlet: 'userCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'userPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section core-packages', =>
            @h3 outlet: 'corePackagesHeader', class: 'sub-section-heading icon icon-package', =>
              @text 'Core Packages'
              @span outlet: 'coreCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'corePackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section dev-packages', =>
            @h3 outlet: 'devPackagesHeader', class: 'sub-section-heading icon icon-package', =>
              @text 'Development Packages'
              @span outlet: 'devCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'devPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section git-packages', =>
            @h3 outlet: 'gitPackagesHeader', class: 'sub-section-heading icon icon-package', =>
              @text 'Git Packages'
              @span outlet: 'gitCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'gitPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

  initialize: (@packageManager) ->
    super
    @itemViews = {}
    @filterEditor.getModel().onDidStopChanging => @matchPackages()

    @handleEvents()
    @loadPackages()

  focus: ->
    @filterEditor.focus()

  dispose: ->
    return

  extractDeprecated: (packageLists) ->
    deprecated = _.filter packageLists.user.getItems(), (pack) ->
      pack.isDeprecated()

    if deprecated
      packageLists.deprecated = new List('name')
      packageLists.deprecated.setItems deprecated

    packageLists

  loadPackages: ->
    @packageManager.getPackageList('installed:packages')
      .then (lists) =>
        @extractDeprecated(lists)
      .then (packageLists) =>
        @packages = packageLists

        if @packages.deprecated.length() > 0
          @deprecatedSection.show()
        else
          @deprecatedSection.hide()

        _.each @packages, (packagesList, listName) =>
          if section = @["#{listName}Packages"]
            packagesList.sort(packageComparatorAscending)
            @itemViews[listName] = new ListView(packagesList, section, @createPackageCard)
            @itemViews[listName].emitter.on 'updated', =>
              @updateSectionCounts()
              @matchPackages()

            section.find('.alert.loading-area').remove()

      .then =>
        @updateSectionCounts()
        @matchPackages()
        @packageManager.reloadCachedLists()
      .catch (error) =>
        console.error error
        @updateErrors.append(new ErrorView(@packageManager, error))

  createPackageCard: (pack) ->
    packageRow = $$ -> @div class: 'row'
    packView = new PackageCard(pack, {back: 'Packages'})
    packageRow.append(packView)
    packageRow
