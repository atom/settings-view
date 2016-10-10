_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'

module.exports =
class PackageUpdatesStatusView extends View
  @content: ->
    @div class: 'package-updates-status-view inline-block text text-info', =>
      @span class: 'icon icon-package'
      @span outlet: 'countLabel', class: 'available-updates-status'

  initialize: (statusBar, packages) ->
    @countLabel.text("#{_.pluralize(packages.length, 'update')}")
    @tooltip = atom.tooltips.add(@element, title: "#{_.pluralize(packages.length, 'package update')} available")
    # Priority of -99 should put us just to the left of the Squirrel icon, which displays when Atom has updates available
    @tile = statusBar.addRightTile(item: this, priority: -99)

    @on 'click', =>
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:check-for-package-updates')
      @tooltip.dispose()
      @tile.destroy()
