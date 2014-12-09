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
      @section class: 'section settings-filter', =>
        @div class: 'section-container', =>
          @div class: 'section-heading icon icon-package', =>
            @text 'My Packages & Themes'
            @span outlet: 'totalPackages', class:'section-heading-count', ' (…)'
          @div outlet: 'checkingMessage', class: 'alert alert-info featured-message icon icon-hourglass', 'Checking for updates\u2026'
          @div outlet: 'noUpdatesMessage', class: 'alert alert-info featured-message icon icon-heart', 'All of your installed packages are up to date!'
          @div outlet: 'updateMessage', class: 'alert alert-info loading-area icon icon-cloud-download', =>
            @a outlet: 'updateLink', "Updates available"
          @div class: 'editor-container', =>
            @subview 'filterEditor', new TextEditorView(mini: true, placeholderText: 'Filter packages by name')

      @section class: 'section installed-packages', =>
        @div class: 'section-container', =>
          @h2 class: 'section-heading icon icon-package', =>
            @text 'Community Packages'
            @span outlet: 'communityCount', class:'section-heading-count', ' (…)'
          @div outlet: 'communityPackages', class: 'container package-container', =>
            @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

      @section class: 'section core-packages', =>
        @div class: 'section-container', =>
          @h2 class: 'section-heading icon icon-package', =>
            @text 'Core Packages'
            @span outlet: 'coreCount', class:'section-heading-count', ' (…)'
          @div outlet: 'corePackages', class: 'container package-container', =>
            @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

      @section class: 'section dev-packages', =>
        @div class: 'section-container', =>
          @h2 class: 'section-heading icon icon-package', =>
            @text 'Development Packages'
            @span outlet: 'devCount', class:'section-heading-count', ' (…)'
          @div outlet: 'devPackages', class: 'container package-container', =>
            @div class: 'alert alert-info loading-area icon icon-hourglass', "Loading packages…"

  initialize: (@packageManager) ->
    @packageViews = []
    @noUpdatesMessage.hide()
    @updateMessage.hide()

    @subscribe @packageManager, 'package-install-failed', (pack, error) =>
      @searchErrors.append(new ErrorView(@packageManager, error))

    @subscribe @packageManager, 'package-update-failed theme-update-failed', (pack, error) =>
      @updateErrors.append(new ErrorView(@packageManager, error))

    @filterEditor.getEditor().on 'contents-modified', =>
      @matchPackages()

    @checkForUpdates()
    @loadPackages()

  checkForUpdates: ->
    @checkingMessage.show()

    @packageManager.getOutdated()
      .then (updates) =>
        if updates.length > 0
          @updateLink.text("#{updates.length} updates available…")
            .on 'click', () =>
              @parents('.settings-view').view()?.showPanel('Available Updates', {back: 'My Packages & Themes', updates: updates})
          @updateMessage.show()
          @checkingMessage.hide()
        else

      .catch (error) =>
        @checkingMessage.hide()
        @updateErrors.append(new ErrorView(@packageManager, error))


  loadPackages: ->
    @packageViews = []
    @packageManager.getInstalled()
      .then (packages) =>
        @packages = packages

        # @loadingMessage.hide()
        # TODO show empty mesage per section
        # @emptyMessage.show() if packages.length is 0
        @totalPackages.text " (#{@packages.user.length + @packages.core.length + @packages.dev.length})"

        _.each @addPackageViews(@communityPackages, @packages.user), (v) => @packageViews.push(v)
        @communityCount.text " (#{@packages.user.length})"

        _.each @addPackageViews(@corePackages, @packages.core), (v) => @packageViews.push(v)
        @coreCount.text " (#{@packages.core.length})"

        _.each @addPackageViews(@devPackages, @packages.dev), (v) => @packageViews.push(v)
        @devCount.text " (#{@packages.dev.length})"

      .catch (error) =>
        @loadingMessage.hide()
        # TODO errors by section
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
      # TODO if pack.valid?
      packView = new AvailablePackageView(pack, @packageManager)
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

    @totalPackages.text " (#{active.length}/#{@packageViews.length})"
    @updateSectionCounts()

  updateSectionCounts: ->
    filterText = @filterEditor.getEditor().getText()
    if filterText is ''
      @totalPackages.text " (#{@packages.user.length + @packages.core.length + @packages.dev.length})"
      @communityCount.text " (#{@packages.user.length})"
      @coreCount.text " (#{@packages.core.length})"
      @devCount.text " (#{@packages.dev.length})"
    else
      community = @communityPackages.find('.available-package-view:not(.hidden)').length
      @communityCount.text " (#{community}/#{@packages.user.length})"
      dev = @devPackages.find('.available-package-view:not(.hidden)').length
      @devCount.text " (#{dev}/#{@packages.dev.length})"
      core = @corePackages.find('.available-package-view:not(.hidden)').length
      @coreCount.text " (#{core}/#{@packages.core.length})"


  # TODO rename this and the below
  matchPackages: ->
    filterText = @filterEditor.getEditor().getText()
    @filterPackageListByText(filterText)
