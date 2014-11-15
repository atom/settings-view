{View} = require 'atom'

class PackageCardView extends View
  @content: ({name, description, owner, stars, version, repo}) ->
    @div class: 'package-card', =>
      @div class: 'body', =>
        @h4 class: 'package-name', =>
          @span outlet: 'packageName', =>
            @a =>
        @span outlet: 'packageDescription', class: 'package-description', =>
      @div class: 'meta', =>
        @a outlet: 'avatarLink', =>
          @img class: 'avatar'
        @a outlet: 'loginLink', =>
        @div class: 'meta-right', =>
          @span class: 'stat', =>
            @span class: 'octicon octicon-cloud-download'
            @span outlet: 'downloadCount', class: 'value'
          @span class: 'star-wrap', =>
            @div class: 'star-box', =>
              @a outlet: 'starButton', class: 'star-button', =>
                @span class: 'octicon octicon-star'
              @a outlet: 'starCount', class: 'star-count'

  @initialize: ->
