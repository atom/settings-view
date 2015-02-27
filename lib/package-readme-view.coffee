path = require 'path'
_ = require 'underscore-plus'
{$, $$$, View} = require 'atom-space-pen-views'
roaster = require 'roaster'
fs = require 'fs'

# Displays the readme for a package, if it has one
# TODO Decide to keep this or current button-to-new-tab view
module.exports =
class PackageReadmeView extends View
  @content: ->
    @section class: 'section', =>
      @div class: 'section-heading icon icon-book', 'README'
      @div class: 'package-readme', outlet: 'packageReadme'

  initialize: (readme) ->
    readme = readme || "### No README."
    roaster readme, (err, content) =>
      if err
        @packageReadme.append("<h3>Error parsing README</h3>")
      @packageReadme.append(content)
