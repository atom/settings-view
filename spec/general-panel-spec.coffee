GeneralPanel = require '../lib/general-panel'

describe "GeneralPanel", ->
  panel = null

  getValueForId = (id) ->
    element = panel.find("##{id.replace('.', '\\.')}")
    if element.is("input")
      element.prop('checked')
    else
      element.view().getText()

  setValueForId = (id, value) ->
    element = panel.find("##{id.replace('.', '\\.')}")
    if element.is("input")
      element.prop('checked', value)
      element.change()
    else
      element.view().setText(value?.toString())
      window.advanceClock(10000) # wait for contents-modified to be triggered


  beforeEach ->
    atom.config.set('core.int', 22)
    atom.config.set('core.float', 0.1)
    atom.config.set('editor.boolean', true)
    atom.config.set('editor.string', 'hey')

    panel = new GeneralPanel()

  it "automatically binds named fields to their corresponding config keys", ->
    expect(getValueForId('core.int')).toBe '22'
    expect(getValueForId('core.float')).toBe '0.1'
    expect(getValueForId('editor.boolean')).toBeTruthy()
    expect(getValueForId('editor.string')).toBe 'hey'

    atom.config.set('core.int', 222)
    atom.config.set('core.float', 0.11)
    atom.config.set('editor.boolean', false)
    atom.config.set('editor.string', 'hey again')

    expect(getValueForId('core.int')).toBe '222'
    expect(getValueForId('core.float')).toBe '0.11'
    expect(getValueForId('editor.boolean')).toBeFalsy()
    expect(getValueForId('editor.string')).toBe 'hey again'

    setValueForId('core.int', 90)
    setValueForId('core.float', 89.2)
    setValueForId('editor.string', "oh hi")
    setValueForId('editor.boolean', true)

    expect(atom.config.get('core.int')).toBe 90
    expect(atom.config.get('core.float')).toBe 89.2
    expect(atom.config.get('editor.boolean')).toBe true
    expect(atom.config.get('editor.string')).toBe 'oh hi'

    setValueForId('core.int', '')
    setValueForId('core.float', '')
    setValueForId('editor.string', '')

    expect(atom.config.get('core.int')).toBeUndefined()
    expect(atom.config.get('core.float')).toBeUndefined()
    expect(atom.config.get('editor.string')).toBeUndefined()

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
