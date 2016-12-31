_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'

module.exports =
class PackageUpdatesStatusView extends View
  @content: ->
    @div class: 'package-updates-status-view inline-block text text-info', =>
      @span class: 'icon icon-package'
      @span outlet: 'countLabel', class: 'available-updates-status'

  initialize: (@statusBar, packageManager, @updates) ->
    @destroyed = true
    @updatingPackages = []
    @failedUpdates = []

    packageManager.on 'package-update-available theme-update-available', ({pack, error}) => @onPackageUpdateAvailable(pack)
    packageManager.on 'package-updating theme-updating', ({pack, error}) => @onPackageUpdating(pack)
    packageManager.on 'package-updated theme-updated', ({pack, error}) => @onPackageUpdated(pack)
    packageManager.on 'package-update-failed theme-update-failed', ({pack, error}) => @onPackageUpdateFailed(pack)

    @updateTile()

    @on 'click', ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:check-for-package-updates')

  onPackageUpdateAvailable: (pack) ->
    for update in @updates
      if update.name is pack.name
        return

    @updates.push(pack)
    @updateTile()

  onPackageUpdating: (pack) ->
    @updatingPackages.push(pack)
    @updateTile()

  onPackageUpdated: (pack) ->
    for index, update of @updates
      if update.name is pack.name
        @updates.splice(index, 1)

    for index, update of @updatingPackages
      if update.name is pack.name
        @updatingPackages.splice(index, 1)

    for index, update of @failedUpdates
      if update.name is pack.name
        @failedUpdates.splice(index, 1)

    @updateTile()

  onPackageUpdateFailed: (pack) ->
    for update in @failedUpdates
      if update.name is pack.name
        return

    for index, update of @updatingPackages
      if update.name is pack.name
        @updatingPackages.splice(index, 1)

    @failedUpdates.push(pack)
    @updateTile()

  updateTile: ->
    if @updates.length
      if @destroyed
        # Priority of -99 should put us just to the left of the Squirrel icon, which displays when Atom has updates available
        @tile = @statusBar.addRightTile(item: this, priority: -99)
        @destroyed = false

      @tooltip?.dispose()
      labelText = "#{_.pluralize(@updates.length, 'update')}" # 5 updates
      tooltipText = "#{_.pluralize(@updates.length, 'package update')} available"

      if @updatingPackages.length
        labelText = "#{@updatingPackages.length}/#{@updates.length} updating" # 3/5 updating
        tooltipText += ", #{_.pluralize(@updatingPackages.length, 'package')} currently updating"

      if @failedUpdates.length
        labelText += " (#{@failedUpdates.length} failed)" # 1 update (1 failed), or 3/5 updating (1 failed)
        tooltipText += ", #{_.pluralize(@failedUpdates.length, 'failed update')}"

      @countLabel.text(labelText)
      @tooltip = atom.tooltips.add(@element, title: tooltipText)
    else if not @destroyed
      @tooltip?.dispose()
      @tile.destroy()
      @destroyed = true
