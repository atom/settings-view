KeybindingPanel = require '../lib/keybinding-panel'

describe "KeybindingPanel", ->
  panel = null

  describe "loads and displays core key bindings", ->
    beforeEach ->
      expect(global.keymap).toBeDefined
      spyOn(global.keymap, 'getKeyBindings').andReturn [
        source: '/atom', keystroke: 'ctrl-a', command: 'core:select-all', selector: '.editor'
      ]
      panel = new KeybindingPanel

    it "shows exactly one row", ->
      expect(panel.keybindingRows.children().length).toBe 1

      row = panel.keybindingRows.find(':first')
      expect(row.find(':nth-child(1)').text()).toBe 'ctrl-a'
      expect(row.find(':nth-child(2)').text()).toBe 'core:select-all'
      expect(row.find(':nth-child(3)').text()).toBe 'Core'
      expect(row.find(':nth-child(4)').text()).toBe '.editor'
