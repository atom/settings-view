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
      atom.config.setSchema("foo", config)
      atom.config.setDefaults("foo", gong: 'gong')
      expect(_.size(atom.config.get('foo'))).toBe 5
      settingsPanel = new SettingsPanel("foo", {includeTitle: false})

    it "sorts settings by order and then alphabetically by the key", ->
      settings = atom.config.get('foo')
      expect(_.size(settings)).toBe 5
      sortedSettings = settingsPanel.sortSettings("foo", settings)
      expect(sortedSettings[0]).toBe 'zing'
      expect(sortedSettings[1]).toBe 'zang'
      expect(sortedSettings[2]).toBe 'bar'
      expect(sortedSettings[3]).toBe 'gong'
      expect(sortedSettings[4]).toBe 'haz'

    it "gracefully deals with a null settings object", ->
      sortedSettings = settingsPanel.sortSettings("foo", null)
      expect(sortedSettings).not.toBeNull
      expect(_.size(sortedSettings)).toBe 0

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
      settingsPanel = new SettingsPanel('foo', {includeTitle: false})

    it 'ensures that only grouped settings have a group title', ->
      expect(settingsPanel.find('.section-container > .section-body')).toHaveLength 1
      sectionBody = settingsPanel.find('.section-body:first')
      expect(sectionBody.find('>.control-group')).toHaveLength 3
      firstControlGroup = sectionBody.find('>.control-group:nth(0)')
      expect(firstControlGroup.find('.sub-section .sub-section-heading')).toHaveLength 1
      expect(firstControlGroup.find('.sub-section .sub-section-heading:first').text()).toBe 'Bar group'
      expect(firstControlGroup.find('.sub-section .sub-section-body')).toHaveLength 1
      subsectionBody = firstControlGroup.find('.sub-section .sub-section-body:first')
      expect(subsectionBody.find('.control-group')).toHaveLength 1
      secondControlGroup = sectionBody.find('>.control-group:nth(1)')
      expect(secondControlGroup.find('.sub-section .sub-section-heading')).toHaveLength 1
      expect(secondControlGroup.find('.sub-section .sub-section-heading:first').text()).toBe 'Baz Group'
      expect(secondControlGroup.find('.sub-section .sub-section-body')).toHaveLength 1
      subsectionBody = secondControlGroup.find('.sub-section .sub-section-body:first')
      expect(subsectionBody.find('.control-group')).toHaveLength 1
      thirdControlGroup = sectionBody.find('>.control-group:nth(2)')
      expect(thirdControlGroup.find('.sub-section')).toHaveLength 0
      expect(thirdControlGroup.find('.sub-section-heading')).toHaveLength 0
