{_, $, $$, Editor, EventEmitter, stringscore, View} = require 'atom-api'
PackageView = require './package-view'
packageManager = require './package-manager'


### Internal ###
class PackageEventEmitter
_.extend PackageEventEmitter.prototype, EventEmitter

module.exports =
class PackagePanel extends View
  @content: ->
    @div class: 'package-panel section', =>
      @h1 class: 'section-heading', 'Packages'
      @ul class: 'nav nav-tabs block', =>
        @li class: 'active', =>
          @a 'Installed', =>
            @span class: 'badge pull-right', outlet: 'installedCount'
        @li =>
          @a 'Available', =>
            @span class: 'badge pull-right', outlet: 'availableCount'

      @div class: 'block', =>
        @subview 'packageFilter', new Editor(mini: true)
        @div class: 'errors', outlet: 'errors'
      @div outlet: 'installedPackages'
      @div outlet: 'availablePackages'

  initialize: ->
    @packageEventEmitter = new PackageEventEmitter()

    @availablePackages.hide()
    @loadInstalledViews()
    @loadAvailableViews()

    @find('.nav-tabs li').on 'click', (event) =>
      return if $(event.currentTarget).hasClass('active')
      @find('.nav-tabs li').toggleClass('active')
      @availablePackages.toggle()
      @installedPackages.toggle()

    @packageEventEmitter.on 'package-installed', (error, pack) =>
      if error?
        @showPackageError(error)
      else
        @addInstalledPackage(pack)

    @packageEventEmitter.on 'package-uninstalled', (error, pack) =>
      if error?
        @showPackageError(error)
      else
        @removeInstalledPackage(pack)

    @packageFilter.getBuffer().on 'contents-modified', =>
      @filterPackages(@packageFilter.getText())

  loadInstalledViews: ->
    @installedPackages.empty()
    @installedPackages.append @createLoadingView('Loading installed packages\u2026')

    packages = _.sortBy(atom.getAvailablePackageMetadata(), 'name')
    packageManager.renderMarkdownInMetadata packages, =>
      @installedPackages.empty()
      for pack in packages
        view = new PackageView(pack, @packageEventEmitter)
        @installedPackages.append(view)

      @updateInstalledCount()

  loadAvailableViews: ->
    @availablePackages.empty()
    @availablePackages.append @createLoadingView('Loading available packages\u2026')

    packageManager.getAvailable (error, @packages=[]) =>
      @availablePackages.empty()
      if error?
        errorView =  $$ ->
          @div class: 'alert alert-error', =>
            @span 'Error fetching available packages.'
            @button class: 'btn btn-mini btn-retry', 'Retry'
        errorView.on 'click', => @loadAvailableViews()
        @availablePackages.append errorView
        console.error(error.stack ? error)
      else
        for pack in @packages
          view = new PackageView(pack, @packageEventEmitter)
          @availablePackages.append(view)

      @updateAvailableCount()

  showPackageError: (error) ->
    console.error(error.stack ? error)
    errorView = @createErrorView(error.message, error.stderr)
    @errors.append(errorView)
    @parent().scrollTop(errorView.offset().top - @offset().top)

  createLoadingView: (text) ->
    $$ ->
      @div class: 'alert alert-info loading-area', text

  createErrorView: (text, details='') ->
    view = $$ ->
      @div class: 'alert alert-error', =>
        @button type: 'button', class: 'close', 'data-dismiss': 'alert', 'aria-hidden': true, '\u00d7'
        @span class: 'error-message', "#{text} "
        @a class: 'toggle-details', 'More information\u2026'
        @pre class: 'error-details', details
    view.on 'click', '.close', -> view.remove()
    view.on 'click', '.toggle-details', ->
      if view.find('.error-details').toggle().isVisible()
        $(this).text('Less information\u2026')
      else
        $(this).text('More information\u2026')
    view.find('.error-details').hide()
    view

  updateInstalledCount: ->
    @installedCount.text(@installedPackages.children().length)

  updateAvailableCount: ->
    @availableCount.text(@availablePackages.children().length)

  removeInstalledPackage: ({name}) ->
    @installedPackages.children("[name=#{name}]").remove()
    @updateInstalledCount()

  addInstalledPackage: (pack) ->
    packageNames = [pack.name]
    @installedPackages.children().each (index, el) -> packageNames.push(el.getAttribute('name'))
    packageNames.sort()
    insertAfterIndex = packageNames.indexOf(pack.name) - 1

    view = new PackageView(pack, @packageEventEmitter)
    if insertAfterIndex < 0
      @installedPackages.prepend(view)
    else
      @installedPackages.children(":eq(#{insertAfterIndex})").after(view)

    @updateInstalledCount()

  filterPackages: (filterString) ->
    for children in [@installedPackages.children(), @availablePackages.children()]
      for packageView in children
        name = packageView.getAttribute('name')
        continue unless name
        if /^\s*$/.test(filterString) or stringScore(name, filterString)
          $(packageView).show()
        else
          $(packageView).hide()
