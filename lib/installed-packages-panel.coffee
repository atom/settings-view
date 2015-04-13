_ = require 'underscore-plus'
{$$, TextEditorView, View} = require 'atom-space-pen-views'
{Subscriber} = require 'emissary'
fuzzaldrin = require 'fuzzaldrin'

PackageCard = require './package-card'
ErrorView = require './error-view'

module.exports =
class InstalledPackagesPanel extends View
  Subscriber.includeInto(this)

  @content: ->
    @div =>
      @section class: 'section', =>
        @div class: 'section-container', =>
          @div class: 'section-heading icon icon-package', =>
            @text 'Installed Packages'
            @span outlet: 'totalPackages', class:'section-heading-count badge badge-flexible', '…'
          @div class: 'editor-container', =>
            @subview 'filterEditor', new TextEditorView(mini: true, placeholderText: 'Filter packages by name')

          @div outlet: 'updateErrors'

          @section class: 'sub-section installed-packages', =>
            @h3 class: 'sub-section-heading icon icon-package', =>
              @text 'Community Packages'
              @span outlet: 'communityCount', class:'section-heading-count badge badge-flexible', '…'
            @div outlet: 'communityPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section core-packages', =>
            @h3 class: 'sub-section-heading icon icon-package', =>
              @text 'Core Packages'
              @span outlet: 'coreCount', class:'section-heading-count badge badge-flexible', '…'
            @div outlet: 'corePackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

          @section class: 'sub-section dev-packages', =>
            @h3 class: 'sub-section-heading icon icon-package', =>
              @text 'Development Packages'
              @span outlet: 'devCount', class:'section-heading-count badge badge-flexible', '…'
            @div outlet: 'devPackages', class: 'container package-container', =>
              @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

  initialize: (@packageManager) ->
    @packageViews = []

    @subscribe @packageManager, 'package-install-failed theme-install-failed package-uninstall-failed theme-uninstall-failed package-update-failed theme-update-failed', (pack, error) =>
      @updateErrors.append(new ErrorView(@packageManager, error))

    @filterEditor.getModel().onDidStopChanging => @matchPackages()

    @loadPackages()

  focus: ->
    @filterEditor.focus()

  detached: ->
    @unsubscribe()

  filterPackages: (packages) ->
    packages.dev = packages.dev.filter ({theme}) -> not theme
    packages.user = packages.user.filter ({theme}) -> not theme
    packages.core = packages.core.filter ({theme}) -> not theme

    packages

  loadPackages: ->
    @packageViews = []
    @packageManager.getInstalled()
      .then (packages) =>
        @packages =  @filterPackages(packages)

        # @loadingMessage.hide()
        # TODO show empty mesage per section
        # @emptyMessage.show() if packages.length is 0
        @totalPackages.text @packages.user.length + @packages.core.length + @packages.dev.length

        _.each @addPackageViews(@communityPackages, @packages.user), (v) => @packageViews.push(v)
        @communityCount.text @packages.user.length

        @packages.core.forEach (p) ->
          # Assume core packages are in the atom org
          p.repository ?= "https://github.com/atom/#{p.name}"

        _.each @addPackageViews(@corePackages, @packages.core), (v) => @packageViews.push(v)
        @coreCount.text @packages.core.length

        _.each @addPackageViews(@devPackages, @packages.dev), (v) => @packageViews.push(v)
        @devCount.text @packages.dev.length

      .catch (error) =>
        @loadingMessage.hide()
        @featuredErrors.append(new ErrorView(@packageManager, error))

  addPackageViews: (container, packages) ->
    container.empty()
    packageViews = []

    packages.sort (left, right) ->
      leftStatus = atom.packages.isPackageDisabled(left.name)
      rightStatus = atom.packages.isPackageDisabled(right.name)
      if leftStatus == rightStatus
        return 0
      else if leftStatus > rightStatus
        return 1
      else
        return -1

    for pack, index in packages
      packageRow = $$ -> @div class: 'row'
      container.append(packageRow)
      packView = new PackageCard(pack, @packageManager, {back: 'Packages'})
      packageViews.push(packView) # used for search filterin'
      packageRow.append(packView)

    packageViews

  filterPackageListByText: (text) ->
    return unless @packages
    active = fuzzaldrin.filter(@packageViews, text, key: 'filterText')

    _.each @packageViews, (view) ->
      # should set an attribute on the view we can filter by it instead of doing
      # dumb jquery stuff
      view.hide().addClass('hidden')
    _.each active, (view) ->
      view.show().removeClass('hidden')

    @totalPackages.text "#{active.length}/#{@packageViews.length}"
    @updateSectionCounts()

  updateSectionCounts: ->
    filterText = @filterEditor.getModel().getText()
    if filterText is ''
      @totalPackages.text @packages.user.length + @packages.core.length + @packages.dev.length
      @communityCount.text @packages.user.length
      @coreCount.text @packages.core.length
      @devCount.text @packages.dev.length
    else
      community = @communityPackages.find('.package-card:not(.hidden)').length
      @communityCount.text "#{community}/#{@packages.user.length}"
      dev = @devPackages.find('.package-card:not(.hidden)').length
      @devCount.text "#{dev}/#{@packages.dev.length}"
      core = @corePackages.find('.package-card:not(.hidden)').length
      @coreCount.text "#{core}/#{@packages.core.length}"

  matchPackages: ->
    filterText = @filterEditor.getModel().getText()
    @filterPackageListByText(filterText)
