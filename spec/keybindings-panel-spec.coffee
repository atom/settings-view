path = require 'path'
KeybindingsPanel = require '../lib/keybindings-panel'

describe "KeybindingsPanel", ->
  [keyBindings, panel] = []

  beforeEach ->
    expect(atom.keymaps).toBeDefined()
    keyBindings = [
      {
        source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-a'
        command: 'core:select-all'
        selector: '.editor, .platform-test'
      }
      {
        source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-u'
        command: 'core:undo'
        selector: ".platform-test"
      }
      {
        source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps"
        keystrokes: 'ctrl-u'
        command: 'core:undo'
        selector: ".platform-a, .platform-b"
      }
    ]
    spyOn(atom.keymaps, 'getKeyBindings').andReturn(keyBindings)
    panel = new KeybindingsPanel

  it "loads and displays core key bindings", ->
    expect(panel.keybindingRows.children().length).toBe 1

    row = panel.keybindingRows.children(':first')
    expect(row.find('.keystroke').text()).toBe 'ctrl-a'
    expect(row.find('.command').text()).toBe 'core:select-all'
    expect(row.find('.source').text()).toBe 'Core'
    expect(row.find('.selector').text()).toBe '.editor, .platform-test'

  describe "when a keybinding is copied", ->
    describe "when the keybinding file ends in .cson", ->
      it "writes a CSON snippet to the clipboard", ->
        spyOn(atom.keymaps, 'getUserKeymapPath').andReturn 'keymap.cson'
        panel.find('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          '.editor, .platform-test':
            'ctrl-a': 'core:select-all'
        """

    describe "when the keybinding file ends in .json", ->
      it "writes a JSON snippet to the clipboard", ->
        spyOn(atom.keymaps, 'getUserKeymapPath').andReturn 'keymap.json'
        panel.find('.copy-icon').click()
        expect(atom.clipboard.read()).toBe """
          ".editor, .platform-test": {
            "ctrl-a": "core:select-all"
          }
        """

  describe "when the key bindings change", ->
    it "reloads the key bindings", ->
      keyBindings.push
        source: atom.keymaps.getUserKeymapPath(), keystrokes: 'ctrl-b', command: 'core:undo', selector: '.editor'
      atom.keymaps.emitter.emit 'did-reload-keymap'

      waitsFor ->
        panel.keybindingRows.children().length is 2

      runs ->
        row = panel.keybindingRows.children(':last')
        expect(row.find('.keystroke').text()).toBe 'ctrl-b'
        expect(row.find('.command').text()).toBe 'core:undo'
        expect(row.find('.source').text()).toBe 'User'
        expect(row.find('.selector').text()).toBe '.editor'

  describe "when searching key bindings", ->
    it "find case-insensitive results", ->
      keyBindings.push
        source: "#{atom.getLoadSettings().resourcePath}#{path.sep}keymaps", keystrokes: 'F11', command: 'window:toggle-full-screen', selector: 'body'
      atom.keymaps.emitter.emit 'did-reload-keymap'

      panel.filterKeyBindings keyBindings, 'f11'

      expect(panel.keybindingRows.children().length).toBe 1

      row = panel.keybindingRows.children(':first')
      expect(row.find('.keystroke').text()).toBe 'F11'
      expect(row.find('.command').text()).toBe 'window:toggle-full-screen'
      expect(row.find('.source').text()).toBe 'Core'
      expect(row.find('.selector').text()).toBe 'body'
