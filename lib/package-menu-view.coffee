_ = require 'underscore-plus'
{View} = require 'atom'

# Menu item view for an installed package
module.exports =
class PackageMenuView extends View
  @content: ->
    @li =>
      @a outlet: 'link', class: 'icon'

  initialize: (@pack, @packageManager) ->
    @attr('name', @pack.name)
    @attr('type', 'package')
    @link.text(_.undasherize(_.uncamelcase(@pack.name)))

    @checkForUpdates()

    @subscribe @packageManager, 'package-updated theme-updated', ({name}) =>
      @link.removeClass('icon-squirrel') if @pack.name is name

  checkForUpdates: ->
    return if atom.packages.isBundledPackage(@pack.name)

    @getAvailablePackage (availablePackage) =>
      if @packageManager.canUpgrade(@pack, availablePackage)
        @link.addClass('icon-squirrel')

  getAvailablePackage: (callback) ->
    @packageManager.getAvailable().then (packages) =>
      for pack in packages when pack.name is @pack.name
        return callback(pack)

      callback()
