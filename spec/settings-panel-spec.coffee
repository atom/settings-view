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
      settingsPanel = new SettingsPanel("foo", {includeTitle: false})

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
