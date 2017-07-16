SettingsPanel = require '../lib/settings-panel'
_ = require 'underscore-plus'

describe "SettingsPanel", ->
  settingsPanel = null

  describe "sorted settings", ->
    beforeEach ->
      config =
        type: 'object'
        properties:
          bar:
            title: 'Bar'
            description: 'The bar setting'
            type: 'boolean'
            default: true
          haz:
            title: 'Haz'
            description: 'The haz setting'
            type: 'string'
            default: 'haz'
          zing:
            title: 'Zing'
            description: 'The zing setting'
            type: 'string'
            default: 'zing'
            order: 1
          zang:
            title: 'Zang'
            description: 'The baz setting'
            type: 'string'
            default: 'zang'
            order: 100
          enum:
            title: 'An enum'
            type: 'string'
            default: 'one'
            enum: [
              {value: 'one', description: 'One'}
              'Two'
            ]
      atom.config.setSchema("foo", config)
      atom.config.setDefaults("foo", gong: 'gong')
      expect(_.size(atom.config.get('foo'))).toBe 6
      settingsPanel = new SettingsPanel({namespace: "foo", includeTitle: false})

    it "sorts settings by order and then alphabetically by the key", ->
      settings = atom.config.get('foo')
      expect(_.size(settings)).toBe 6
      sortedSettings = settingsPanel.sortSettings("foo", settings)
      expect(sortedSettings[0]).toBe 'zing'
      expect(sortedSettings[1]).toBe 'zang'
      expect(sortedSettings[2]).toBe 'bar'
      expect(sortedSettings[3]).toBe 'enum'
      expect(sortedSettings[4]).toBe 'gong'
      expect(sortedSettings[5]).toBe 'haz'

    it "gracefully deals with a null settings object", ->
      sortedSettings = settingsPanel.sortSettings("foo", null)
      expect(sortedSettings).not.toBeNull
      expect(_.size(sortedSettings)).toBe 0

    it "presents enum options with their descriptions", ->
      select = settingsPanel.element.querySelector('#foo\\.enum')
      pairs = ([opt.value, opt.innerText] for opt in select.children)
      expect(pairs).toEqual([['one', 'One'], ['Two', 'Two']])

  describe 'default settings', ->
    beforeEach ->
      config =
        type: 'object'
        properties:
          haz:
            name: 'haz'
            title: 'Haz'
            description: 'The haz setting'
            type: 'string'
            default: 'haz'
          testZero:
            name: 'testZero'
            title: 'Test Zero'
            description: 'Setting for testing zero as a default'
            type: 'integer'
            default: 0
      atom.config.setSchema("foo", config)
      atom.config.setDefaults("foo", gong: 'gong')
      expect(_.size(atom.config.get('foo'))).toBe 3
      settingsPanel = new SettingsPanel({namespace: "foo", includeTitle: false})

    it 'ensures default stays default', ->
      expect(settingsPanel.getDefault('foo.haz')).toBe 'haz'
      expect(settingsPanel.isDefault('foo.haz')).toBe true
      settingsPanel.set('foo.haz', 'haz')
      expect(settingsPanel.isDefault('foo.haz')).toBe true

    it 'can be overwritten', ->
      expect(settingsPanel.getDefault('foo.haz')).toBe 'haz'
      expect(settingsPanel.isDefault('foo.haz')).toBe true
      settingsPanel.set('foo.haz', 'newhaz')
      expect(settingsPanel.isDefault('foo.haz')).toBe false
      expect(atom.config.get('foo.haz')).toBe 'newhaz'

    # Regression test for #783
    it 'allows 0 to be a default', ->
      expect(settingsPanel.getDefault('foo.testZero')).toBe 0
      expect(settingsPanel.isDefault('foo.testZero')).toBe true
      settingsPanel.set('foo.testZero', 15)
      expect(settingsPanel.isDefault('foo.testZero')).toBe false
      settingsPanel.set('foo.testZero', 0)
      expect(settingsPanel.isDefault('foo.testZero')).toBe true

    describe 'scoped settings', ->
      beforeEach ->
        schema =
          scopes:
            '.source.python':
              default: 4

        atom.config.setScopedDefaultsFromSchema('editor.tabLength', schema)
        expect(atom.config.get('editor.tabLength')).toBe(2)

      it 'displays the scoped default', ->
        settingsPanel = new SettingsPanel({namespace: "editor", includeTitle: false, scopeName: '.source.python'})
        tabLengthEditor = settingsPanel.element.querySelector('[id="editor.tabLength"]')
        expect(tabLengthEditor.getModel().getText()).toBe('')
        expect(tabLengthEditor.getModel().getPlaceholderText()).toBe('Default: 4')

      it 'allows the scoped setting to be changed to its normal default if the unscoped value is different', ->
        atom.config.set('editor.tabLength', 8)

        settingsPanel = new SettingsPanel({namespace: "editor", includeTitle: false, scopeName: '.source.js'})
        tabLengthEditor = settingsPanel.element.querySelector('[id="editor.tabLength"]')
        expect(tabLengthEditor.getModel().getText()).toBe('')
        expect(tabLengthEditor.getModel().getPlaceholderText()).toBe('Default: 8')

        # This is the unscoped default, but it differs from the current unscoped value
        settingsPanel.set('editor.tabLength', 2)
        expect(tabLengthEditor.getModel().getText()).toBe('2')
        expect(atom.config.get('editor.tabLength', {scope: ['source.js']})).toBe(2)

      it 'allows the scoped setting to be changed to the unscoped default if it is different', ->
        settingsPanel = new SettingsPanel({namespace: "editor", includeTitle: false, scopeName: '.source.python'})
        tabLengthEditor = settingsPanel.element.querySelector('[id="editor.tabLength"]')
        expect(tabLengthEditor.getModel().getText()).toBe('')
        expect(tabLengthEditor.getModel().getPlaceholderText()).toBe('Default: 4')

        # This is the unscoped default, but it differs from the scoped default
        settingsPanel.set('editor.tabLength', 2)
        expect(tabLengthEditor.getModel().getText()).toBe('2')
        expect(atom.config.get('editor.tabLength', {scope: ['source.python']})).toBe(2)

  describe 'grouped settings', ->
    beforeEach ->
      config =
        type: 'object'
        properties:
          barGroup:
            type: 'object'
            title: 'Bar group'
            properties:
              bar:
                title: 'Bar'
                description: 'The bar setting'
                type: 'boolean'
                default: false
          bazGroup:
            type: 'object'
            collapsed: true
            properties:
              baz:
                title: 'Baz'
                description: 'The baz setting'
                type: 'boolean'
                default: false
          zing:
            type: 'string'
            default: ''
      atom.config.setSchema('foo', config)
      expect(_.size(atom.config.get('foo'))).toBe 3
      settingsPanel = new SettingsPanel({namespace: 'foo', includeTitle: false})

    it 'ensures that only grouped settings have a group title', ->
      expect(settingsPanel.element.querySelectorAll('.section-container > .section-body')).toHaveLength 1
      controlGroups = settingsPanel.element.querySelectorAll('.section-body > .control-group')
      expect(controlGroups).toHaveLength 3
      expect(controlGroups[0].querySelectorAll('.sub-section .sub-section-heading')).toHaveLength 1
      expect(controlGroups[0].querySelector('.sub-section .sub-section-heading').textContent).toBe 'Bar group'
      expect(controlGroups[0].querySelectorAll('.sub-section .sub-section-body')).toHaveLength 1
      subsectionBody = controlGroups[0].querySelector('.sub-section .sub-section-body')
      expect(subsectionBody.querySelectorAll('.control-group')).toHaveLength 1
      expect(controlGroups[1].querySelectorAll('.sub-section .sub-section-heading')).toHaveLength 1
      expect(controlGroups[1].querySelector('.sub-section .sub-section-heading').textContent).toBe 'Baz Group'
      expect(controlGroups[1].querySelectorAll('.sub-section .sub-section-body')).toHaveLength 1
      subsectionBody = controlGroups[1].querySelector('.sub-section .sub-section-body')
      expect(subsectionBody.querySelectorAll('.control-group')).toHaveLength 1
      expect(controlGroups[2].querySelectorAll('.sub-section')).toHaveLength 0
      expect(controlGroups[2].querySelectorAll('.sub-section-heading')).toHaveLength 0

    it 'ensures grouped settings are collapsable', ->
      expect(settingsPanel.element.querySelectorAll('.section-container > .section-body')).toHaveLength 1
      controlGroups = settingsPanel.element.querySelectorAll('.section-body > .control-group')
      expect(controlGroups).toHaveLength 3
      # Bar group
      expect(controlGroups[0].querySelectorAll('.sub-section .sub-section-heading')).toHaveLength 1
      expect(controlGroups[0].querySelector('.sub-section .sub-section-heading').classList.contains('has-items')).toBe true
      # Baz Group
      expect(controlGroups[1].querySelectorAll('.sub-section .sub-section-heading')).toHaveLength 1
      expect(controlGroups[1].querySelector('.sub-section .sub-section-heading').classList.contains('has-items')).toBe true
      # Should be already collapsed
      expect(controlGroups[1].querySelector('.sub-section .sub-section-heading').parentElement.classList.contains('collapsed')).toBe true
