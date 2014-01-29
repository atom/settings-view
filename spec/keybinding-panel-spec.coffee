path = require 'path'
KeybindingPanel = require '../lib/keybinding-panel'

describe "KeybindingPanel", ->
  panel = null

  describe "loads and displays core key bindings", ->
    beforeEach ->
      expect(atom.keymap).toBeDefined()
      spyOn(atom.keymap, 'getKeyBindings').andReturn [
        source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps", keystroke: 'ctrl-a', command: 'core:select-all', selector: '.editor'
      ]
      panel = new KeybindingPanel

    it "shows exactly one row", ->
      expect(panel.keybindingRows.children().length).toBe 1

      row = panel.keybindingRows.find(':first')
      expect(row.find('.keystroke').text()).toBe 'ctrl-a'
      expect(row.find('.command').text()).toBe 'core:select-all'
      expect(row.find('.source').text()).toBe 'Core'
      expect(row.find('.selector').text()).toBe '.editor'
