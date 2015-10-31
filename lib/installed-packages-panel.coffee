_ = require 'underscore-plus'
{TextEditorView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'

CollapsibleSectionPanel = require './collapsible-section-panel'
ErrorView = require './error-view'

List = require './list'
ListView = require './list-view'

module.exports =
class InstalledPackagesPanel extends CollapsibleSectionPanel
  @loadPackagesDelay: 300

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
            @h3 outlet: 'communityPackagesHeader', class: 'sub-section-heading icon icon-package', =>
              @text 'Community Packages'
              @span outlet: 'communityCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'communityPackages', class: 'container package-container', =>
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

  initialize: (@packageManager) ->
    super
    @items =
      dev: new List('name')
      core: new List('name')
      user: new List('name')
      deprecated: new List('name')
    @itemViews =
      dev: new ListView(@items.dev, @devPackages, @createPackageCard)
      core: new ListView(@items.core, @corePackages, @createPackageCard)
      user: new ListView(@items.user, @communityPackages, @createPackageCard)
      deprecated: new ListView(@items.deprecated, @deprecatedPackages, @createPackageCard)

    @filterEditor.getModel().onDidStopChanging => @matchPackages()

    @disposables = new CompositeDisposable
    @disposables.add @packageManager.on 'package-install-failed theme-install-failed package-uninstall-failed theme-uninstall-failed package-update-failed theme-update-failed', ({pack, error}) =>
      @updateErrors.append(new ErrorView(@packageManager, error))

    loadPackagesTimeout = null
    @disposables.add @packageManager.on 'package-updated package-installed package-uninstalled package-installed-alternative', =>
      clearTimeout(loadPackagesTimeout)
      loadPackagesTimeout = setTimeout =>
        @loadPackages()
      , InstalledPackagesPanel.loadPackagesDelay

    @handleEvents()
    @loadPackages()

  filterPackages: (packages) ->
    packages.dev = packages.dev.filter ({theme}) -> not theme
    packages.user = packages.user.filter ({theme}) -> not theme
    packages.deprecated = packages.user.filter ({name, version}) -> atom.packages.isDeprecatedPackage(name, version)
    packages.core = packages.core.filter ({theme}) -> not theme

    @setRepositoryAndOwner(packages)

  loadPackages: ->
    packagesWithUpdates = {}
    @packageManager.getOutdated().then (packages) =>
      for {name, latestVersion} in packages
        packagesWithUpdates[name] = latestVersion
      @displayPackageUpdates(packagesWithUpdates)

    @packageManager.getInstalled()
      .then (packages) =>
        @packages = @sortPackages(@filterPackages(packages))
        @devPackages.find('.alert.loading-area').remove()
        @items.dev.setItems(@packages.dev)

        @corePackages.find('.alert.loading-area').remove()
        @items.core.setItems(@packages.core)

        @communityPackages.find('.alert.loading-area').remove()
        @items.user.setItems(@packages.user)

        if @packages.deprecated.length
          @deprecatedSection.show()
        else
          @deprecatedSection.hide()
        @deprecatedPackages.find('.alert.loading-area').remove()
        @items.deprecated.setItems(@packages.deprecated)

        # TODO show empty mesage per section

        @updateSectionCounts()
        @displayPackageUpdates(packagesWithUpdates)

        @matchPackages()

      .catch (error) =>
        console.error error.message, error.stack
        @loadingMessage.hide()
        @featuredErrors.append(new ErrorView(@packageManager, error))

  displayPackageUpdates: (packagesWithUpdates) ->
    for packageType in ['dev', 'core', 'user', 'deprecated']
      for packageView in @itemViews[packageType].getViews()
        packageCard = packageView.find('.package-card').view()
        if newVersion = packagesWithUpdates[packageCard.pack.name]
          packageCard.displayAvailableUpdate(newVersion)

  createPackageCard: (pack) =>
    super(pack, 'Packages')

  filterPackageListByText: (text) ->
    @filterPackageListByTextAndType(text, ['dev', 'core', 'user', 'deprecated'])

  updateUnfilteredSectionCounts: ->
    @updateSectionCount(@deprecatedPackagesHeader, @deprecatedCount, @packages.deprecated.length)
    @updateSectionCount(@communityPackagesHeader, @communityCount, @packages.user.length)
    @updateSectionCount(@corePackagesHeader, @coreCount, @packages.core.length)
    @updateSectionCount(@devPackagesHeader, @devCount, @packages.dev.length)

    @totalPackages.text(@packages.user.length + @packages.core.length + @packages.dev.length)

  updateFilteredSectionCounts: ->
    deprecated = @notHiddenCardsLength(@deprecatedPackages)
    @updateSectionCount(@deprecatedPackagesHeader, @deprecatedCount, deprecated, @packages.deprecated.length)

    community = @notHiddenCardsLength(@communityPackages)
    @updateSectionCount(@communityPackagesHeader, @communityCount, community, @packages.user.length)

    core = @notHiddenCardsLength(@corePackages)
    @updateSectionCount(@corePackagesHeader, @coreCount, core, @packages.core.length)

    dev = @notHiddenCardsLength @devPackages
    @updateSectionCount(@devPackagesHeader, @devCount, dev, @packages.dev.length)

    shownPackages = dev + core + community
    totalPackages = @packages.user.length + @packages.core.length + @packages.dev.length
    @totalPackages.text "#{shownPackages}/#{totalPackages}"

  resetSectionHasItems: ->
    @resetCollapsibleSections([@deprecatedPackagesHeader, @communityPackagesHeader, @corePackagesHeader, @devPackagesHeader])
