path = require 'path'
_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
{$$$, View} = require 'atom-space-pen-views'
SettingsPanel = require './settings-panel'

# View to display the grammars that a package has registered.
module.exports =
class PackageGrammarsView extends View
  @content: ->
    @section class: 'package-grammars', =>
      @div outlet: 'grammarSettings'

  initialize: (packagePath) ->
    @disposables = new CompositeDisposable()
    @packagePath = path.join(packagePath, path.sep)
    @addGrammars()

    @disposables.add atom.grammars.onDidAddGrammar => @addGrammars()
    @disposables.add atom.grammars.onDidUpdateGrammar => @addGrammars()

  dispose: ->
    @disposables.dispose()

  getPackageGrammars: ->
    packageGrammars = []
    grammars = atom.grammars.grammars ? []
    for grammar in grammars when grammar.path
      packageGrammars.push(grammar) if grammar.path.indexOf(@packagePath) is 0
    packageGrammars.sort (grammar1, grammar2) ->
      name1 = grammar1.name ? grammar1.scopeName ? ''
      name2 = grammar2.name ? grammar2.scopeName ? ''
      name1.localeCompare(name2)

  addGrammarHeading: (grammar, panel) ->
    panel.find('.section-body').prepend $$$ ->
      @div class: 'native-key-bindings text', tabindex: -1, =>
        @div class: 'grammar-scope', =>
          @strong 'Scope: '
          @span grammar.scopeName ? ''
        @div class: 'grammar-filetypes', =>
          @strong 'File Types: '
          @span grammar.fileTypes?.join(', ') ? ''

  addGrammars: ->
    @grammarSettings.empty()

    for grammar in @getPackageGrammars()
      {scopeName} = grammar
      continue unless scopeName
      scopeName = ".#{scopeName}" unless scopeName.startsWith('.')

      title = "#{grammar.name} Grammar"
      panel = new SettingsPanel(null, {title, scopeName, icon: 'puzzle'})
      @addGrammarHeading(grammar, panel)
      @grammarSettings.append(panel)
