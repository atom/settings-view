path = require 'path'
KeybindingsPanel = require '../lib/keybindings-panel'

describe "KeybindingsPanel", ->
  panel = null

  beforeEach ->
    expect(atom.keymap).toBeDefined()
    spyOn(atom.keymap, 'getKeyBindings').andReturn [
      source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps", keystroke: 'ctrl-a', command: 'core:select-all', selector: '.editor'
    ]
    panel = new KeybindingsPanel

  it "loads and displays core key bindings", ->
    expect(panel.keybindingRows.children().length).toBe 1

    row = panel.keybindingRows.find(':first')
    expect(row.find('.keystroke').text()).toBe 'ctrl-a'
    expect(row.find('.command').text()).toBe 'core:select-all'
    expect(row.find('.source').text()).toBe 'Core'
    expect(row.find('.selector').text()).toBe '.editor'

  describe "when a keybinding is copied", ->
    describe "when the keybinding file ends in .cson", ->
      it "writes a CSON snippet to the clipboard", ->
        spyOn(atom.keymap, 'getUserKeymapPath').andReturn 'keymap.cson'
        panel.find('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          '.editor':
            'ctrl-a': 'core:select-all'
        """

    describe "when the keybinding file ends in .json", ->
      it "writes a JSON snippet to the clipboard", ->
        spyOn(atom.keymap, 'getUserKeymapPath').andReturn 'keymap.json'
        panel.find('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          ".editor": {
            "ctrl-a": "core:select-all"
          }
        """
