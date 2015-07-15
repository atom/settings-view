{$, $$, ScrollView} = require 'atom-space-pen-views'
{Subscriber} = require 'emissary'
ErrorView = require './error-view'
PackageUpdateView = require './package-update-view'

module.exports =
class UpdatesPanel extends ScrollView
  Subscriber.includeInto(this)

  @content: ->
    @div tabindex: 0, class: 'panels-item', =>
      @section class: 'section packages', =>
        @div class: 'section-container updates-container', =>
          @h1 class: 'section-heading icon icon-cloud-download', 'Available Updates', =>
            @button outlet: 'updateAllButton', class: 'pull-right update-all-button btn btn-primary', 'Update All'
            @button outlet: 'checkButton', class: 'pull-right update-all-button btn btn', 'Check for Updates'

          @div class: 'text native-key-bindings', tabindex: -1, =>
            @span class: 'icon icon-question'
            @span 'Deprecated APIs will be removed when Atom 1.0 is released in June. Please update your packages. '
            @a class: 'link', outlet: 'openBlogPost', 'Learn more\u2026'

          @div outlet: 'updateErrors'
          @div outlet: 'checkingMessage', class: 'alert alert-info featured-message icon icon-hourglass', 'Checking for updates\u2026'
          @div outlet: 'noUpdatesMessage', class: 'alert alert-info featured-message icon icon-heart', 'All of your installed packages are up to date!'
          @div outlet: 'updatesContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    super
    @updateAllButton.on 'click', =>
      @updateAllButton.prop('disabled', true)
      for updateView in @updatesContainer.find('.package-update-view')
        $(updateView).view()?.upgrade?()
    @checkButton.on 'click', =>
      @checkForUpdates()

    @checkForUpdates()

    @openBlogPost.on 'click', ->
      require('shell').openExternal('http://blog.atom.io/2015/05/01/removing-deprecated-apis.html')
      false

    @subscribe @packageManager, 'package-update-failed theme-update-failed', (pack, error) =>
      @updateErrors.append(new ErrorView(@packageManager, error))

  detached: ->
    @unsubscribe()

  beforeShow: (opts) ->
    if opts?.back
      @breadcrumb.text(opts.back).on 'click', =>
        @parents('.settings-view').view()?.showPanel(opts.back)
    if opts?.updates
      @availableUpdates = opts.updates
      @addUpdateViews()
    else
      @availableUpdates = []
      @updatesContainer.empty()
      @checkForUpdates()

  # Check for updates and display them
  checkForUpdates: ->
    @noUpdatesMessage.hide()
    @updateAllButton.hide()
    @checkButton.prop('disabled', true)

    @checkingMessage.show()

    @packageManager.getOutdated()
      .then (@availableUpdates) =>
        @checkButton.prop('disabled', false)
        @addUpdateViews()
      .catch (error) =>
        @checkButton.prop('disabled', false)
        @checkingMessage.hide()
        @updateErrors.append(new ErrorView(@packageManager, error))

  addUpdateViews: ->
    @updateAllButton.show() if @availableUpdates.length > 0
    @checkingMessage.hide()
    @updatesContainer.empty()
    @noUpdatesMessage.show() if @availableUpdates.length is 0

    for pack, index in @availableUpdates
      if index % 2 is 0
        packageRow = $$ -> @div class: 'row'
        @updatesContainer.append(packageRow)

      packageRow.append(new PackageUpdateView(pack, @packageManager))
