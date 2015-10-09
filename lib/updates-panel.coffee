{$, $$, ScrollView} = require 'atom-space-pen-views'
ErrorView = require './error-view'
PackageCard = require './package-card'

module.exports =
class UpdatesPanel extends ScrollView

  @content: ->
    @div tabindex: 0, class: 'panels-item', =>
      @section class: 'section packages', =>
        @div class: 'section-container updates-container', =>
          @h1 class: 'section-heading icon icon-cloud-download', 'Available Updates', =>
            @button outlet: 'updateAllButton', class: 'pull-right update-all-button btn btn-primary', 'Update All'
            @button outlet: 'checkButton', class: 'pull-right update-all-button btn btn', 'Check for Updates'

          @div outlet: 'updateErrors'
          @div outlet: 'checkingMessage', class: 'alert alert-info icon icon-hourglass', 'Checking for updates\u2026'
          @div outlet: 'noUpdatesMessage', class: 'alert alert-info icon icon-heart', 'All of your installed packages are up to date!'
          @div outlet: 'updatesContainer', class: 'container package-container'

  initialize: (@packageManager) ->
    super
    @updateAllButton.on 'click', =>
      @updateAllButton.prop('disabled', true)
      for packageCard in @updatesContainer.find('.package-card')
        $(packageCard).view()?.update?()
    @checkButton.on 'click', =>
      @checkForUpdates()

    @checkForUpdates()

    @packageManagerSubscription = @packageManager.on 'package-update-failed theme-update-failed', ({pack, error}) =>
      @updateErrors.append(new ErrorView(@packageManager, error))

  dispose: ->
    @packageManagerSubscription.dispose()

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

    @packageManager.getInstalled().then =>
      @packageManager.getOutdated()
        .then (@availableUpdates) =>
          @checkButton.prop('disabled', false)
          @addUpdateViews()
        .catch (error) =>
          @checkButton.prop('disabled', false)
          @checkingMessage.hide()
          @updateErrors.append(new ErrorView(@packageManager, error))

  addUpdateViews: ->
    if @availableUpdates.length > 0
      @updateAllButton.show()
      @updateAllButton.prop('disabled', false)
    @checkingMessage.hide()
    @updatesContainer.empty()
    @noUpdatesMessage.show() if @availableUpdates.length is 0

    for pack in @availableUpdates
      @updatesContainer.append(new PackageCard(pack, @packageManager, {back: 'Updates'}))
