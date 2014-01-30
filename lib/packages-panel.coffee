_ = require 'underscore-plus'
{$$, View} = require 'atom'

PackageManager = require './package-manager'
PackageInstallView = require './package-install-view'

module.exports =
class PackagesPanel extends View
  @content: ->
    @div =>
      @div class: 'section packages', =>
        @div class: 'section-heading theme-heading icon icon-cloud-download', 'Install Packages'
        @div outlet: 'loadingMessage', class: 'padded text icon icon-hourglass', 'Loading packages\u2026'
        @div outlet: 'emptyMessage', class: 'padded text icon icon-heart', 'You have every package installed already!'
        @div outlet: 'packageContainer', class: 'container package-container', ->

  initialize: (@packageManager) ->
    @loadAvailablePackages()

  # Load and display the packages that are available to install.
  loadAvailablePackages: ->
    @loadingMessage.show()
    @emptyMessage.hide()

    @packageManager.getAvailable (error, packages=[]) =>
      installedPackages = atom.packages.getAvailablePackageNames()
      packages = packages.filter ({name, theme}) ->
        not theme and not (name in installedPackages)

      @loadingMessage.hide()
      if packages.length > 0
        for pack,index in packages
          if index % 4 is 0
            packageRow = $$ -> @div class: 'row'
            @packageContainer.append(packageRow)
          packageRow.append(new PackageInstallView(pack, @packageManager))
      else
        @emptyMessage.show()
