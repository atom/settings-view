{ScrollView} = require 'atom-space-pen-views'
SettingsPanel = require './settings-panel'
Registry = require 'winreg'
Path = require 'path'

exeName = Path.basename(process.execPath)
appPath = "\"#{process.execPath}\""
appName = exeName.replace('atom', 'Atom').replace('beta', 'Beta').replace('.exe', '')

fileHandlerRegistry = {
  key: "\\Software\\Classes\\Applications\\#{exeName}",
  parts: [{key: 'shell\\open\\command', name: '', value: "#{appPath} \"%1\""}]
}

contextRegistryParts = [
    {key: 'command', name: '', value: "#{appPath} \"%1\""},
    {name: '', value: "Open with #{appName}"},
    {name: 'Icon', value: "#{appPath}"}
]

contextFileRegistry = {
  key: "\\Software\\Classes\\*\\shell\\#{appName}",
  parts: contextRegistryParts
}

contextFolderRegistry = {
  key: "\\Software\\Classes\\Directory\\shell\\#{appName}",
  parts: contextRegistryParts
}

contextFolderBackgroundRegistry = {
  key: "\\Software\\Classes\\Directory\\background\\shell\\#{appName}",
  parts: JSON.parse(JSON.stringify(contextRegistryParts).replace('%1', '%V'))
}

module.exports =
class SystemPanel extends ScrollView
  @content: ->
    @div tabindex: 0, class: 'panels-item', =>
      @form class: 'general-panel section', =>
        @div class: 'settings-panel', =>
          @div class: 'section-container', =>
            @div class: 'block section-heading icon icon-device-desktop', 'System settings'
            @div class: 'text icon icon-question', 'These settings determine how Atom integrates with your operating system.'
            @div class: 'section-body', =>
              @div class: 'control-group', =>
                @div class: 'controls', =>
                  @div class: 'checkbox', =>
                    @label for: 'system.windows.file-handler', =>
                      @input outlet: 'fileHandlerCheckbox', id: 'system.windows.file-handler', type: 'checkbox'
                      @div class: 'setting-title', 'Register as file handler'
                      @div class: 'setting-description', =>
                        @raw('Show Atom in the "Open with" application list for easy association with file types.')
              @div class: 'control-group', =>
                @div class: 'controls', =>
                  @div class: 'checkbox', =>
                    @label for: 'system.windows.shell-menu-files', =>
                      @input outlet: 'contextFileCheckbox', id: 'system.windows.shell-menu-files', type: 'checkbox'
                      @div class: 'setting-title', 'Show in file context menus'
                      @div class: 'setting-description', =>
                        @raw('Add "Open with Atom" to the File Explorer context menu for files.')
              @div class: 'control-group', =>
                @div class: 'controls', =>
                  @div class: 'checkbox', =>
                    @label for: 'system.windows.shell-menu-folders', =>
                      @input outlet: 'contextFolderCheckbox', id: 'system.windows.shell-menu-folders', type: 'checkbox'
                      @div class: 'setting-title', 'Show in folder context menus'
                      @div class: 'setting-description', =>
                        @raw('Add "Open with Atom" to the File Explorer context menu for folders.')

  initialize: ->
    super
    @checkRegistry(fileHandlerRegistry, (isSet) => @fileHandlerCheckbox.prop('checked', isSet))
    @checkRegistry(contextFileRegistry, (isSet) => @contextFileCheckbox.prop('checked', isSet))
    @checkRegistry(contextFolderRegistry, (isSet) => @contextFolderCheckbox.prop('checked', isSet))

    @fileHandlerCheckbox.on 'click', (e) => @updateRegistry(fileHandlerRegistry, e.target.checked, -> )
    @contextFileCheckbox.on 'click', (e) => @updateRegistry(contextFileRegistry, e.target.checked, -> )
    @contextFolderCheckbox.on 'click', (e) =>
      @updateRegistry(contextFolderRegistry, e.target.checked, -> )
      @updateRegistry(contextFolderBackgroundRegistry, e.target.checked, -> )

  updateRegistry: (area, shouldBeSet, callback) ->
    if shouldBeSet
      @setRegistry(area, callback)
    else
      @clearRegistry(area, callback)

  checkRegistry: (area, callback) ->
    new Registry({hive: 'HKCU', key: "#{area.key}\\#{area.parts[0].key}"})
      .get(area.parts[0].name, (err, val) -> callback(not err? and val.value is area.parts[0].value))

  setRegistry: (area, callback) ->
    doneCount = area.parts.length
    area.parts.forEach((part) ->
      reg = new Registry({hive: 'HKCU', key: if part.key? then "#{area.key}\\#{part.key}" else area.key})
      reg.create( -> reg.set(part.name, Registry.REG_SZ, part.value, -> callback() if doneCount-- is 0))
    )

  clearRegistry: (area, callback) ->
    new Registry({hive: 'HKCU', key: area.key})
      .destroy(callback)
