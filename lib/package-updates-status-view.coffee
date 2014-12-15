_ = require 'underscore-plus'
{View} = require 'atom-space-pen-views'

module.exports =
class PackageUpdatesStatusView extends View
  @content: ->
    @div class: 'inline-block text text-info', =>
      @span class: 'icon icon-package'
      @span outlet: 'countLabel', class: 'available-updates-status'

  initialize: (statusBar, packages) ->
    @countLabel.text(packages.length)
    @setTooltip("#{_.pluralize(packages.length, 'package update')} available")
    statusBar.appendRight(this)

    @on 'click', =>
      atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:check-for-package-updates')
      @destroyTooltip()
      @remove()
