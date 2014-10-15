path = require 'path'
_ = require 'underscore-plus'
{$$$, View} = require 'atom'

# View to display the grammars that a package has registered.
module.exports =
class PackageGrammarsView extends View
  @content: ->
    @section =>
      @div class: 'section-heading icon icon-puzzle', 'Grammars'
      @table class: 'package-grammars-table table native-key-bindings text', tabindex: -1, =>
        @thead =>
          @tr =>
            @th 'Name'
            @th 'Scope'
            @th 'File Types'
        @tbody outlet: 'grammarItems'

  initialize: (packagePath) ->
    @packagePath = path.join(packagePath, path.sep)
    @addGrammars()
    @subscribe atom.syntax, 'grammar-added grammar-updated', => @addGrammars()

  getPackageGrammars: ->
    packageGrammars = []
    grammars = atom.syntax.grammars ? []
    for grammar in grammars when grammar.path
      packageGrammars.push(grammar) if grammar.path.indexOf(@packagePath) is 0
    packageGrammars.sort (grammar1, grammar2) ->
      name1 = grammar1.name ? grammar1.scopeName ? ''
      name2 = grammar2.name ? grammar2.scopeName ? ''
      name1.localeCompare(name2)

  addGrammars: ->
    @grammarItems.empty()

    for {name, fileTypes, scopeName} in @getPackageGrammars()
      @grammarItems.append $$$ ->
        @tr =>
          @td name ? ''
          @td scopeName ? ''
          @td class: 'grammar-table-filetypes', fileTypes?.join(', ') ? ''

    if @grammarItems.children().length > 0
      @show()
    else
      @hide()
