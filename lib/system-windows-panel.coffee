{ScrollView} = require 'atom-space-pen-views'
{WinShell} = require 'atom'

module.exports =
class SystemPanel extends ScrollView
  @content: ->
    @div class: 'panels-item', =>
      @form class: 'general-panel section', =>
        @div class: 'settings-panel', =>
          @div class: 'section-container', =>
            @div class: 'block section-heading icon icon-device-desktop', 'System Settings'
            @div class: 'text icon icon-question', 'These settings determine how Atom integrates with your operating system.'
            @div class: 'section-body', =>
              @div class: 'control-group', =>
                @div class: 'controls', =>
                  @div class: 'checkbox', =>
                    @label for: 'system.windows.file-handler', =>
                      @input outlet: 'fileHandlerCheckbox', id: 'system.windows.file-handler', type: 'checkbox'
                      @div class: 'setting-title', 'Register as file handler'
                      @div class: 'setting-description', =>
                        @raw("Show #{WinShell.appName} in the \"Open with\" application list for easy association with file types.")
              @div class: 'control-group', =>
                @div class: 'controls', =>
                  @div class: 'checkbox', =>
                    @label for: 'system.windows.shell-menu-files', =>
                      @input outlet: 'fileContextMenuCheckbox', id: 'system.windows.shell-menu-files', type: 'checkbox'
                      @div class: 'setting-title', 'Show in file context menus'
                      @div class: 'setting-description', =>
                        @raw("Add \"Open with #{WinShell.appName}\" to the File Explorer context menu for files.")
              @div class: 'control-group', =>
                @div class: 'controls', =>
                  @div class: 'checkbox', =>
                    @label for: 'system.windows.shell-menu-folders', =>
                      @input outlet: 'folderContextMenuCheckbox', id: 'system.windows.shell-menu-folders', type: 'checkbox'
                      @div class: 'setting-title', 'Show in folder context menus'
                      @div class: 'setting-description', =>
                        @raw("Add \"Open with #{WinShell.appName}\" to the File Explorer context menu for folders.")

  initialize: ->
    super
    WinShell.fileHandler.isRegistered (i) => @fileHandlerCheckbox.prop('checked', i)
    WinShell.fileContextMenu.isRegistered (i) => @fileContextMenuCheckbox.prop('checked', i)
    WinShell.folderContextMenu.isRegistered (i) => @folderContextMenuCheckbox.prop('checked', i)

    @fileHandlerCheckbox.on 'click', (e) => @setRegistration WinShell.fileHandler, e.target.checked
    @fileContextMenuCheckbox.on 'click', (e) => @setRegistration WinShell.fileContextMenu, e.target.checked
    @folderContextMenuCheckbox.on 'click', (e) =>
      @setRegistration WinShell.folderContextMenu, e.target.checked
      @setRegistration WinShell.folderBackgroundContextMenu, e.target.checked

  dispose: ->
    return

  setRegistration: (option, shouldBeRegistered) ->
    if shouldBeRegistered
      option.register ->
    else
      option.deregister ->
