_ = require 'underscore-plus'
{$$, TextEditorView, ScrollView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
fuzzaldrin = require 'fuzzaldrin'

PackageCard = require './package-card'
ErrorView = require './error-view'

List = require './list'
ListView = require './list-view'
{ownerFromRepository, packageComparatorAscending} = require './utils'

module.exports =
class InstalledPackagesPanel extends ScrollView
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
            @h3 class: 'sub-section-heading icon icon-package', =>
              @text 'Deprecated Packages'
              @span outlet: 'deprecatedCount', class: 'section-heading-count badge badge-flexible', '…'
            @p 'Atom does not load deprecated packages. These packages may have updates available.'
            @div outlet: 'deprecatedPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section installed-packages', =>
            @h3 class: 'sub-section-heading icon icon-package', =>
              @text 'Community Packages'
              @span outlet: 'communityCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'communityPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section core-packages', =>
            @h3 class: 'sub-section-heading icon icon-package', =>
              @text 'Core Packages'
              @span outlet: 'coreCount', class: 'section-heading-count badge badge-flexible', '…'
            @div outlet: 'corePackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section dev-packages', =>
            @h3 class: 'sub-section-heading icon icon-package', =>
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

    @packageManagerSubscriptions = new CompositeDisposable
    @packageManagerSubscriptions.add @packageManager.on 'package-install-failed theme-install-failed package-uninstall-failed theme-uninstall-failed package-update-failed theme-update-failed', ({pack, error}) =>
      @updateErrors.append(new ErrorView(@packageManager, error))

    loadPackagesTimeout = null
    @packageManagerSubscriptions.add @packageManager.on 'package-updated package-installed package-uninstalled package-installed-alternative', =>
      clearTimeout(loadPackagesTimeout)
      loadPackagesTimeout = setTimeout =>
        @loadPackages()
      , InstalledPackagesPanel.loadPackagesDelay

    @handleEvents()
    @loadPackages()

  focus: ->
    @filterEditor.focus()

  dispose: ->
    @packageManagerSubscriptions.dispose()

  filterPackages: (packages) ->
    packages.dev = packages.dev.filter ({theme}) -> not theme
    packages.user = packages.user.filter ({theme}) -> not theme
    packages.deprecated = packages.user.filter ({name, version}) -> atom.packages.isDeprecatedPackage(name, version)
    packages.core = packages.core.filter ({theme}) -> not theme

    for pack in packages.core
      pack.repository ?= "https://github.com/atom/#{pack.name}"

    for packageType in ['dev', 'core', 'user', 'deprecated']
      for pack in packages[packageType]
        pack.owner = ownerFromRepository(pack.repository)

    packages

  sortPackages: (packages) ->
    packages.dev.sort(packageComparatorAscending)
    packages.core.sort(packageComparatorAscending)
    packages.user.sort(packageComparatorAscending)
    packages.deprecated.sort(packageComparatorAscending)
    packages

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
    packageRow = $$ -> @div class: 'row'
    packView = new PackageCard(pack, @packageManager, {back: 'Packages'})
    packageRow.append(packView)
    packageRow

  filterPackageListByText: (text) ->
    return unless @packages

    for packageType in ['dev', 'core', 'user', 'deprecated']
      allViews = @itemViews[packageType].getViews()
      activeViews = @itemViews[packageType].filterViews (pack) ->
        return true if text is ''
        owner = pack.owner ? ownerFromRepository(pack.repository)
        filterText = "#{pack.name} #{owner}"
        fuzzaldrin.score(filterText, text) > 0

      for view in allViews when view
        view.find('.package-card').hide().addClass('hidden')
      for view in activeViews when view
        view.find('.package-card').show().removeClass('hidden')

    @updateSectionCounts()

  updateSectionCounts: ->
    filterText = @filterEditor.getModel().getText()
    if filterText is ''
      @totalPackages.text(@packages.user.length + @packages.core.length + @packages.dev.length)
      @communityCount.text @packages.user.length
      @coreCount.text @packages.core.length
      @devCount.text @packages.dev.length
      @deprecatedCount.text @packages.deprecated.length
    else
      community = @communityPackages.find('.package-card:not(.hidden)').length
      @communityCount.text "#{community}/#{@packages.user.length}"
      dev = @devPackages.find('.package-card:not(.hidden)').length
      @devCount.text "#{dev}/#{@packages.dev.length}"
      core = @corePackages.find('.package-card:not(.hidden)').length
      @coreCount.text "#{core}/#{@packages.core.length}"
      deprecated = @deprecatedPackages.find('.package-card:not(.hidden)').length
      @deprecatedCount.text "#{deprecated}/#{@packages.deprecated.length}"

      shownPackages = dev + core + community
      totalPackages = @packages.user.length + @packages.core.length + @packages.dev.length
      @totalPackages.text "#{shownPackages}/#{totalPackages}"

  matchPackages: ->
    filterText = @filterEditor.getModel().getText()
    @filterPackageListByText(filterText)

  handleEvents: ->
    @on 'click', '.sub-section .icon-package', (e) ->
      e.currentTarget.parentNode.classList.toggle('collapsed')
