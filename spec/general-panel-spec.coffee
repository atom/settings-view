GeneralPanel = require '../lib/general-panel'

describe "GeneralPanel", ->
  panel = null

  getValueForId = (id) ->
    element = panel.find("##{id.replace(/\./g, '\\.')}")
    if element.is("input")
      element.prop('checked')
    else if element.is("select")
      element.val()
    else
      element.view()?.getText()

  setValueForId = (id, value) ->
    element = panel.find("##{id.replace(/\./g, '\\.')}")
    if element.is("input")
      element.prop('checked', value)
      element.change()
    else if element.is("select")
      element.val(value)
      element.change()
    else
      element.view().setText(value?.toString())
      window.advanceClock(10000) # wait for contents-modified to be triggered

  beforeEach ->
    atom.config.set('core.enum', 4)
    atom.config.set('core.int', 22)
    atom.config.set('core.float', 0.1)

    atom.config.setSchema('', type: 'object')
    atom.config.setSchema('core.enum',
      type: 'integer'
      default: 2
      enum: [2, 4, 6, 8]
    )

    panel = new GeneralPanel()

  it "automatically binds named fields to their corresponding config keys", ->
    expect(getValueForId('core.enum')).toBe '4'
    expect(getValueForId('core.int')).toBe '22'
    expect(getValueForId('core.float')).toBe '0.1'

    atom.config.set('core.enum', 6)
    atom.config.set('core.int', 222)
    atom.config.set('core.float', 0.11)

    expect(getValueForId('core.enum')).toBe '6'
    expect(getValueForId('core.int')).toBe '222'
    expect(getValueForId('core.float')).toBe '0.11'

    setValueForId('core.enum', '2')
    setValueForId('core.int', 90)
    setValueForId('core.float', 89.2)

    expect(atom.config.get('core.enum')).toBe 2
    expect(atom.config.get('core.int')).toBe 90
    expect(atom.config.get('core.float')).toBe 89.2

    setValueForId('core.int', '')
    setValueForId('core.float', '')

    expect(atom.config.get('core.int')).toBeUndefined()
    expect(atom.config.get('core.float')).toBeUndefined()

  it "does not save the config value until it has been changed to a new value", ->
    observeHandler = jasmine.createSpy("observeHandler")
    atom.config.observe "core.int", observeHandler
    observeHandler.reset()

    window.advanceClock(10000) # wait for contents-modified to be triggered
    expect(observeHandler).not.toHaveBeenCalled()

    setValueForId('core.int', 2)
    expect(observeHandler).toHaveBeenCalled()
    observeHandler.reset()

    setValueForId('core.int', 2)
    expect(observeHandler).not.toHaveBeenCalled()

  it "does not update the editor text unless the value it parses to changes", ->
    setValueForId('core.int', "2.")
    expect(atom.config.get('core.int')).toBe 2
    expect(getValueForId('core.int')).toBe '2.'

  it "shows the package settings notes for core and editor settings", ->
    expect(panel.find('#core-settings-note')).toExist()
    expect(panel.find('#core-settings-note').text()).toContain('their package card in')
