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

    packageManager.on 'package-updated theme-updated', ({error, pack}) => @onDidUpdatePackage(pack)
    packageManager.on 'package-update-available theme-update-available', ({error, pack}) => @onPackageUpdateAvailable(pack)

    if @updates.length
      @countLabel.text("#{_.pluralize(@updates.length, 'update')}")
      @tooltip = atom.tooltips.add(@element, title: "#{_.pluralize(@updates.length, 'package update')} available")
      @tile = @statusBar.addRightTile(item: this, priority: 0)
      @destroyed = false

    @on 'click', ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:check-for-package-updates')

  onDidUpdatePackage: (pack) ->
    for index, update of @updates
      if update.name is pack.name
        @updates.splice(index, 1)

    @tooltip.dispose()

    unless @updates.length
      @tile.destroy()
      @destroyed = true
      return

    @countLabel.text("#{_.pluralize(@updates.length, 'update')}")
    @tooltip = atom.tooltips.add(@element, title: "#{_.pluralize(@updates.length, 'package update')} available")

  onPackageUpdateAvailable: (pack) ->
    if @destroyed
      @tile = @statusBar.addRightTile(item: this, priority: 0)
      @destroyed = false

    for update in @updates
      if update.name is pack.name
        return

    @updates.push(pack)
    @tooltip.dispose()

    @countLabel.text("#{_.pluralize(@updates.length, 'update')}")
    @tooltip = atom.tooltips.add(@element, title: "#{_.pluralize(@updates.length, 'package update')} available")
