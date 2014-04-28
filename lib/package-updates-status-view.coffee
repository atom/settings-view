_ = require 'underscore-plus'
{View} = require 'atom'

module.exports =
class PackageUpdatesStatusView extends View
  @content: ->
    @div class: 'inline-block text text-info', =>
        @span class: 'icon icon-package'
        @span outlet: 'countLabel', class: 'available-updates-status'

  initialize: (statusBar, packages) ->
    @countLabel.text(packages.length)
    statusBar.appendRight(this)
    @setTooltip("#{_.pluralize(packages.length, 'package update')} available")

    @subscribe this, 'click', =>
      @trigger('settings-view:install-packages')
      @destroyTooltip()
      @remove()
