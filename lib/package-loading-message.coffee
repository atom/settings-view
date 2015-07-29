{View} = require 'atom-space-pen-views'

module.exports =
class PackageLoadingMessage extends View
  @content: (@name) ->
    @div class: 'package-loading-message col-lg-8', =>
      @h4 "Loading #{@name}"
