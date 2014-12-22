{View} = require 'atom-space-pen-views'
CompileToolsErrorView = require './compile-tools-error-view'

module.exports =
class ErrorView extends View
  @content: ->
    @div class: 'error-message', =>
      @div outlet: 'alert', class: 'alert alert-danger alert-dismissable native-key-bindings', tabindex: -1, =>
        @button outlet: 'close', class: 'close icon icon-x'
        @span outlet: 'message', class: 'native-key-bindings'
        @a outlet: 'detailsLink', class: 'alert-link error-link', 'Show output\u2026'
        @div outlet: 'detailsArea', class: 'padded', =>
          @pre outlet: 'details', class: 'error-details text'

  initialize: (@packageManager, {message, stderr, packageInstallError}) ->
    @message.text(message)

    @detailsArea.hide()
    @details.text(stderr)

    @detailsLink.on 'click', =>
      if @detailsArea.isHidden()
        @detailsArea.show()
        @detailsLink.text('Hide output\u2026')
      else
        @detailsArea.hide()
        @detailsLink.text('Show output\u2026')

      false

    @close.on 'click', => @remove()
    @checkForNativeBuildTools() if packageInstallError

  # Check for native build tools and show warning if missing.
  checkForNativeBuildTools: ->
    return unless process.platform is 'win32'

    @packageManager.checkNativeBuildTools().catch (error) =>
      @alert.append(new CompileToolsErrorView(error))
