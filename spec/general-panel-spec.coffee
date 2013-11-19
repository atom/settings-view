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
    atom.config.set('foo.int', 22)
    atom.config.set('foo.float', 0.1)
    atom.config.set('foo.boolean', true)
    atom.config.set('foo.string', 'hey')

    panel = new GeneralPanel()

  it "automatically binds named fields to their corresponding config keys", ->
    expect(getValueForId('foo.int')).toBe '22'
    expect(getValueForId('foo.float')).toBe '0.1'
    expect(getValueForId('foo.boolean')).toBeTruthy()
    expect(getValueForId('foo.string')).toBe 'hey'

    atom.config.set('foo.int', 222)
    atom.config.set('foo.float', 0.11)
    atom.config.set('foo.boolean', false)
    atom.config.set('foo.string', 'hey again')

    expect(getValueForId('foo.int')).toBe '222'
    expect(getValueForId('foo.float')).toBe '0.11'
    expect(getValueForId('foo.boolean')).toBeFalsy()
    expect(getValueForId('foo.string')).toBe 'hey again'

    setValueForId('foo.int', 90)
    setValueForId('foo.float', 89.2)
    setValueForId('foo.string', "oh hi")
    setValueForId('foo.boolean', true)

    expect(atom.config.get('foo.int')).toBe 90
    expect(atom.config.get('foo.float')).toBe 89.2
    expect(atom.config.get('foo.boolean')).toBe true
    expect(atom.config.get('foo.string')).toBe 'oh hi'

    setValueForId('foo.int', '')
    setValueForId('foo.float', '')
    setValueForId('foo.string', '')

    expect(atom.config.get('foo.int')).toBeUndefined()
    expect(atom.config.get('foo.float')).toBeUndefined()
    expect(atom.config.get('foo.string')).toBeUndefined()

  it "does not save the config value until it has been changed to a new value", ->
    observeHandler = jasmine.createSpy("observeHandler")
    atom.config.observe "foo.int", observeHandler
    observeHandler.reset()

    window.advanceClock(10000) # wait for contents-modified to be triggered
    expect(observeHandler).not.toHaveBeenCalled()

    setValueForId('foo.int', 2)
    expect(observeHandler).toHaveBeenCalled()
    observeHandler.reset()

    setValueForId('foo.int', 2)
    expect(observeHandler).not.toHaveBeenCalled()
