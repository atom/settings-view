_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'

module.exports =
class PackageUpdatesStatusView extends View
  @content: ->
    @div class: 'package-updates-status-view inline-block text text-info', =>
      @span class: 'icon icon-package'
      @span outlet: 'countLabel', class: 'available-updates-status'

  initialize: (@statusBar, @packageList) ->
    @countLabel.text("#{_.pluralize(@packageList.length(), 'update')}")
    @tooltip = atom.tooltips.add(@element, title: "#{_.pluralize(@packageList.length(), 'package update')} available")
    @tile = @statusBar.addRightTile(item: this, priority: -99)

    @on 'click', =>
      @destroy()

    @packageList.onDidChange =>
      new this(@statusBar, @packageList) if @packageList.length() > 0
      @destroy()

  destroy: ->
    atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:check-for-package-updates')
    @tooltip.dispose()
    @tile.destroy()
