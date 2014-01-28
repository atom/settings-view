{_, $, $$, EditorView, View} = require 'atom'
{score} = require 'fuzzaldrin'
{Emitter} = require 'emissary'
PackageView = require './package-view'
packageManager = require './package-manager'

class PackageEventEmitter
  Emitter.includeInto(this)

module.exports =
class PackagesPanel extends View
  @content: ->
    @div class: 'packages-panel section', =>
      @h1 class: 'section-heading', 'Packages'
      @ul class: 'nav nav-tabs block', =>
        @li class: 'active installed-packages', =>
          @a 'Installed Packages', =>
            @span class: 'badge pull-right', outlet: 'installedPackagesCount'
        @li class: 'available-packages', =>
          @a 'Available Packages', =>
            @span class: 'badge pull-right', outlet: 'availablePackagesCount'
        @li class: 'installed-themes', =>
          @a 'Installed Themes', =>
            @span class: 'badge pull-right', outlet: 'installedThemesCount'
        @li class: 'available-themes', =>
          @a 'Available Themes', =>
            @span class: 'badge pull-right', outlet: 'availableThemesCount'

      @div class: 'block', =>
        @subview 'packageFilter', new EditorView(mini: true)
        @div class: 'errors', outlet: 'errors'
      @div class: 'package-container', outlet: 'installedPackages'
      @div class: 'package-container', outlet: 'availablePackages'
      @div class: 'package-container', outlet: 'installedThemes'
      @div class: 'package-container', outlet: 'availableThemes'

  initialize: ->
    @packageFilter.setPlaceholderText('Search')
    @packageEventEmitter = new PackageEventEmitter()

    @availablePackages.hide()
    @loadInstalledViews()
    @loadAvailableViews()

    @find('.nav-tabs li').on 'click', (event) =>
      el = $(event.currentTarget)
      return if el.hasClass('active')

      @find('.nav-tabs li.active').removeClass('active')
      el.addClass('active')
      @find('.package-container').hide()

      if el.hasClass('available-packages')
        @availablePackages.show()
      else if el.hasClass('installed-packages')
        @installedPackages.show()
      else if el.hasClass('available-themes')
        @availableThemes.show()
      else if el.hasClass('installed-themes')
        @installedThemes.show()

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

    @packageFilter.getEditor().getBuffer().on 'contents-modified', =>
      @filterPackages(@packageFilter.getText())

  loadInstalledViews: ->
    @installedPackages.empty()
    @installedPackages.append @createLoadingView('Loading installed packages\u2026')

    packages = _.uniq atom.packages.getAvailablePackageMetadata(), ({name}) -> name
    packages = _.sortBy(packages, 'name')
    packageManager.renderMarkdownInMetadata packages, =>
      @installedPackages.empty()
      @installedThemes.empty()
      for pack in packages
        view = new PackageView(pack, @packageEventEmitter)
        if pack.theme
          @installedThemes.append(view)
        else
          @installedPackages.append(view)

      @updateInstalledPackagesCount()
      @updateInstalledThemesCount()

  loadAvailableViews: ->
    @availablePackages.empty()
    @availablePackages.append @createLoadingView('Loading available packages\u2026')

    packageManager.getAvailable (error, @packages=[]) =>
      @availablePackages.empty()
      @availableThemes.empty()
      if error?
        errorView =  $$ ->
          @div class: 'alert alert-danger error-view', =>
            @span 'Error fetching available packages.'
            @button class: 'btn btn-mini btn-retry', 'Retry'
        errorView.on 'click', => @loadAvailableViews()
        @availablePackages.append errorView
        @logApmError(error)
      else
        installedPackageNames = atom.packages.getAvailablePackageNames()
        @packages = _.sortBy(@packages, 'name')
        for pack in @packages when pack.name not in installedPackageNames
          view = new PackageView(pack, @packageEventEmitter)
          if pack.theme
            @availableThemes.append(view)
          else
            @availablePackages.append(view)

      @updateAvailablePackagesCount()
      @updateAvailableThemesCount()

  showPackageError: (error) ->
    @logApmError(error)
    errorView = @createErrorView(error.message, error.stderr)
    @errors.append(errorView)
    top = errorView.offset().top - @offset().top
    @parent().scrollTop(top) if @parent().scrollTop() > top

  logApmError: (error) ->
    stdout = error.stdout ? ''
    stderr = error.stderr ? ''
    if output = "#{stdout}\n#{stderr}".trim()
      console.error(output)
    console.error(error.stack ? error)

  createLoadingView: (text) ->
    $$ ->
      @div class: 'alert alert-info loading-area', text

  createErrorView: (text, details='') ->
    view = $$ ->
      @div class: 'alert alert-danger alert-dismissable error-view', =>
        @button type: 'button', class: 'close', 'data-dismiss': 'alert', 'aria-hidden': true, '\u00d7'
        @span class: 'error-message', "#{text} "
        @a class: 'alert-link toggle-details', 'More information\u2026'
        @div class: 'padded error-details', =>
          @pre details
    view.on 'click', '.close', -> view.remove()
    view.on 'click', '.toggle-details', ->
      if view.find('.error-details').toggle().isVisible()
        $(this).text('Less information\u2026')
      else
        $(this).text('More information\u2026')
    view.find('.error-details').hide()
    view

  updateInstalledPackagesCount: ->
    @installedPackagesCount.text(@installedPackages.children().length)

  updateAvailablePackagesCount: ->
    @availablePackagesCount.text(@availablePackages.children('.package-view').length)

  updateInstalledThemesCount: ->
    @installedThemesCount.text(@installedThemes.children().length)

  updateAvailableThemesCount: ->
    @availableThemesCount.text(@availableThemes.children('.package-view').length)

  removeInstalledPackage: ({name}) ->
    @installedPackages.children("[name=#{name}]").remove()
    @updateInstalledPackagesCount()
    @updateInstalledThemesCount()

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

    @updateInstalledPackagesCount()
    @updateInstalledThemesCount()

  filterPackages: (filterString) ->
    for children in [@installedPackages.children(), @availablePackages.children(), @installedThemes.children(), @availableThemes.children()]
      for packageView in children
        name = packageView.getAttribute('name')
        continue unless name
        if /^\s*$/.test(filterString) or score(name, filterString)
          $(packageView).show()
        else
          $(packageView).hide()
