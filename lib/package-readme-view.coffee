{$, $$$, View} = require 'atom-space-pen-views'
roaster = require 'roaster'
fs = require 'fs'
cheerio = require 'cheerio'

# Displays the readme for a package, if it has one
# TODO Decide to keep this or current button-to-new-tab view
module.exports =
class PackageReadmeView extends View
  @content: ->
    @section class: 'section', =>
      @div class: 'section-container', =>
        @div class: 'section-heading icon icon-book', 'README'
        @div class: 'package-readme native-key-bindings', tabindex: -1, outlet: 'packageReadme'

  initialize: (readme) ->
    readme = readme or "### No README."
    roaster readme, (err, content) =>
      if err
        @packageReadme.append("<h3>Error parsing README</h3>")
      @packageReadme.append(sanitize(content))

  sanitize = (html) ->
    o = cheerio.load(html)
    o('script').remove()
    attributesToRemove = [
      'onabort'
      'onblur'
      'onchange'
      'onclick'
      'ondbclick'
      'onerror'
      'onfocus'
      'onkeydown'
      'onkeypress'
      'onkeyup'
      'onload'
      'onmousedown'
      'onmousemove'
      'onmouseover'
      'onmouseout'
      'onmouseup'
      'onreset'
      'onresize'
      'onscroll'
      'onselect'
      'onsubmit'
      'onunload'
    ]
    o('*').removeAttr(attribute) for attribute in attributesToRemove
    o.html()
