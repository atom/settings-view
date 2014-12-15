{View} = require 'atom-space-pen-views'

module.exports =
class CompileToolsErrorView extends View
  @content: ->
    @div =>
      @div class: 'icon icon-alert compile-tools-heading compile-tools-message', 'Compiler tools not found'
      @div class: 'compile-tools-message', 'Packages that depend on modules that contain C/C++ code will fail to install.'
      @div class: 'compile-tools-message', =>
        @span 'Read '
        @a class: 'link', href: 'https://atom.io/docs/latest/build-instructions/windows', 'here'
        @span ' for instructions on installing Python and Visual Studio.'
      @div class: 'compile-tools-message', =>
        @span 'Run '
        @code class: 'alert-danger', 'apm install --check'
        @span ' after installing to test compiling a native module.'

  initialize: (error) ->
