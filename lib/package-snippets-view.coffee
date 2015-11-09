path = require 'path'
_ = require 'underscore-plus'
{$$$, View} = require 'atom-space-pen-views'

# View to display the snippets that a package has registered.
module.exports =
class PackageSnippetsView extends View
  @content: ->
    @section class: 'section', =>
      @div class: 'section-heading icon icon-code', 'Snippets'
      @table class: 'package-snippets-table table native-key-bindings text', tabindex: -1, =>
        @thead =>
          @tr =>
            @th 'Trigger'
            @th 'Name'
            @th 'Body'
        @tbody outlet: 'snippets'

  initialize: (packagePath, @snippetsProvider) ->
    @packagePath = path.join(packagePath, path.sep)
    @hide()
    @addSnippets()

  getSnippetProperties: ->
    packageProperties = {}
    for {name, properties} in @snippetsProvider.getSnippets()
      continue unless name?.indexOf?(@packagePath) is 0
      for name, snippet of properties.snippets ? {} when snippet?
        packageProperties[name] ?= snippet

    _.values(packageProperties).sort (snippet1, snippet2) ->
      prefix1 = snippet1.prefix ? ''
      prefix2 = snippet2.prefix ? ''
      prefix1.localeCompare(prefix2)

  getSnippets: (callback) ->
    snippetsPackage = atom.packages.getLoadedPackage('snippets')
    if snippetsModule = snippetsPackage?.mainModule
      if snippetsModule.loaded
        callback(@getSnippetProperties())
      else
        snippetsModule.onDidLoadSnippets => callback(@getSnippetProperties())
    else
      callback([])

  addSnippets: ->
    @getSnippets (snippets) =>
      @snippets.empty()

      for {body, bodyText, name, prefix} in snippets
        name ?= ''
        prefix ?= ''
        body ?= bodyText
        body = body?.replace(/\t/g, '\\t').replace(/\n/g, '\\n') ? ''

        @snippets.append $$$ ->
          @tr =>
            @td class: 'snippet-prefix', prefix
            @td name
            @td class: 'snippet-body', body

      if @snippets.children().length > 0
        @show()
      else
        @hide()
