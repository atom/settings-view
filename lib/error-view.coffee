{View} = require 'atom'

module.exports =
class ErrorView extends View
  @content: ->
    @div class: 'padded error-message', =>
      @div class: 'alert alert-danger alert-dismissable native-key-bindings', tabindex: -1, =>
        @button outlet: 'close', class: 'close icon icon-x'
        @span outlet: 'message', class: 'native-key-bindings'
        @span ' '
        @a outlet: 'detailsLink', class: 'alert-link', 'More\u2026'
        @div outlet: 'detailsArea', class: 'padded', =>
          @pre outlet: 'details', class: 'error-details text'

  initialize: ({message, stderr}) ->
    @message.text(message)

    @detailsArea.hide()
    @details.text(stderr)

    @detailsLink.on 'click', =>
      if @detailsArea.isHidden()
        @detailsArea.show()
        @detailsLink.text('Less\u2026')
      else
        @detailsArea.hide()
        @detailsLink.text('More\u2026')

      false

    @close.on 'click', => @remove()
