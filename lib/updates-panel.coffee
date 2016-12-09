{$, ScrollView} = require 'atom-space-pen-views'
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
    @updateAllButton.on 'click', => @updateAll()
    @checkButton.on 'click', =>
      @checkForUpdates(true)

    @updateAllButton.hide()
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
  checkForUpdates: (clearCache) ->
    @noUpdatesMessage.hide()
    @updateAllButton.prop('disabled', true)
    @checkButton.prop('disabled', true)

    @checkingMessage.show()

    @packageManager.getOutdated(clearCache)
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

  updateAll: ->
    @updateAllButton.prop('disabled', true)

    packageCards = @getPackageCards()
    successfulUpdatesCount = 0
    remainingPackagesCount = packageCards.length
    totalUpdatesCount = packageCards.length # This value doesn't change unlike remainingPackagesCount

    notifyIfDone = =>
      if remainingPackagesCount is 0
        if successfulUpdatesCount > 0
          pluralizedPackages = 'package'
          pluralizedPackages += 's' if successfulUpdatesCount > 1
          message = "Restart Atom to complete the update of #{successfulUpdatesCount} #{pluralizedPackages}."

          buttons = [{
            text: 'Restart',
            onDidClick: -> atom.restartApplication()
          }]
          atom.notifications.addSuccess(message, {dismissable: true, buttons})

        if successfulUpdatesCount is totalUpdatesCount
          @updateAllButton.hide()
        else # Some updates failed
          @updateAllButton.prop('disabled', false)

    onUpdateResolved = ->
      remainingPackagesCount--
      successfulUpdatesCount++
      notifyIfDone()

    onUpdateRejected = ->
      remainingPackagesCount--
      notifyIfDone()

    for packageCard in packageCards
      packageCard.update().then(onUpdateResolved, onUpdateRejected)

  getPackageCards: ->
    @updatesContainer.find('.package-card').toArray()
      .map((element) -> $(element).view())
      .filter((view) -> view?)
