_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'

module.exports =
class PackageUpdatesStatusView extends View
  @content: ->
    @div class: 'package-updates-status-view inline-block text text-info', =>
      @span class: 'icon icon-package'
      @span outlet: 'countLabel', class: 'available-updates-status'

  initialize: (statusBar, packageManager, @updates) ->
    @subscriptions = packageManager.on 'package-updated theme-updated', => @onDidUpdatePackage

    @countLabel.text("#{_.pluralize(@updates, 'update')}")
    @tooltip = atom.tooltips.add(@element, title: "#{_.pluralize(@updates, 'package update')} available")
    @tile = statusBar.addRightTile(item: this, priority: 0)

    @on 'click', ->
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:check-for-package-updates')

  @onDidUpdatePackage: =>
    @updates--
    if @updates is 0
      @tooltip.dispose()
      @tile.destroy()
      return

    @countLabel.text("#{_.pluralize(@updates, 'update')}")
    @tooltip.dispose()
    @tooltip = atom.tooltips.add(@element, title: "#{_.pluralize(@updates, 'package update')} available")
