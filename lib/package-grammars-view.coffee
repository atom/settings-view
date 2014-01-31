path = require 'path'
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
            @th 'File Types'
            @th 'Scope'
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
    packageGrammars

  addGrammars: ->
    @grammarItems.empty()

    for {name, fileTypes, scopeName} in @getPackageGrammars()
      @grammarItems.append $$$ ->
        @tr =>
          @td name ? ''
          @td fileTypes?.join(', ') ? ''
          @td scopeName ? ''

    if @grammarItems.children().length > 0
      @show()
    else
      @hide()
