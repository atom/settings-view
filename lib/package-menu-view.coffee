_ = require 'underscore-plus'
{View} = require 'atom'

# Menu item view for an installed package
module.exports =
class PackageMenuView extends View
  @content: ->
    @li =>
      @a outlet: 'link', class: 'icon', =>
        @span outlet:'nameLabel'
        @span outlet:'packageAuthorLabel', class: 'package-author'

  initialize: (@pack, @packageManager, packageAuthor) ->
    @attr('name', @pack.name)
    @attr('type', 'package')
    @nameLabel.text(@packageManager.getPackageTitle(@pack))
    @packageAuthorLabel.text(@packageManager.getAuthorUserName(@pack))
    @checkForUpdates()
    @subscribe @packageManager, 'package-updated theme-updated', ({name}) =>
      @link.removeClass('icon-squirrel') if @pack.name is name

  checkForUpdates: ->
    return if atom.packages.isBundledPackage(@pack.name)

    @getAvailablePackage (availablePackage) =>
      if @packageManager.canUpgrade(@pack, availablePackage)
        @link.addClass('icon-squirrel')

  getAvailablePackage: (callback) ->
    @packageManager.getPackage(@pack.name).then (availablePackage) ->
      callback(availablePackage)
