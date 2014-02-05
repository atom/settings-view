path = require 'path'
{$$$, View} = require 'atom'

# View to display the snippets that a package has registered.
module.exports =
class PackageSnippetsView extends View
  @content: ->
    @section =>
      @div class: 'section-heading icon icon-code', 'Snippets'
      @table class: 'package-snippets-table table native-key-bindings text', tabindex: -1, =>
        @thead =>
          @tr =>
            @th 'Trigger'
            @th 'Name'
            @th 'Body'
        @tbody outlet: 'snippets'

  initialize: (packagePath) ->
    @packagePath = path.join(packagePath, path.sep)
    @hide()
    @addSnippets()

  getSnippetProperties: ->
    packageProperties = []
    for {name, properties} in atom.syntax.scopedProperties
      continue unless name?.indexOf?(@packagePath) is 0
      for name, snippet of properties.snippets ? {} when snippet?
        packageProperties.push(snippet)

    packageProperties.sort (snippet1, snippet2) ->
      prefix1 = snippet1.prefix ? ''
      prefix2 = snippet2.prefix ? ''
      prefix1.localeCompare(prefix2)

  getSnippets: (callback) ->
    snippetsPackage = atom.packages.getLoadedPackage('snippets')
    if snippetsPackage?.mainModule?
      if snippetsPackage.mainModule.loaded
        callback(@getSnippetProperties())
      else
        @subscribe atom.packages.once 'snippets:loaded', =>
          callback(@getSnippetProperties())
    else
      callback([])

  addSnippets: ->
    @getSnippets (snippets) =>
      @snippets.empty()

      for {bodyText, name, prefix} in snippets
        name ?= ''
        prefix ?= ''
        bodyText = bodyText?.replace(/\t/g, '\\t').replace(/\n/g, '\\n') ? ''

        @snippets.append $$$ ->
          @tr =>
            @td class: 'snippet-prefix', prefix
            @td name
            @td class: 'snippet-body', bodyText

      if @snippets.children().length > 0
        @show()
      else
        @hide()
