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
    atom.config.set('editor.boolean', true)
    atom.config.set('editor.string', 'hey')
    atom.config.set('editor.object', {boolean: true, int: 3, string: 'test'})
    atom.config.set('editor.simpleArray', ['a', 'b', 'c'])
    atom.config.set('editor.complexArray', ['a', 'b', {c: true}])

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
    expect(getValueForId('editor.boolean')).toBeTruthy()
    expect(getValueForId('editor.string')).toBe 'hey'
    expect(getValueForId('editor.object.boolean')).toBeTruthy()
    expect(getValueForId('editor.object.int')).toBe '3'
    expect(getValueForId('editor.object.string')).toBe 'test'

    atom.config.set('core.enum', 6)
    atom.config.set('core.int', 222)
    atom.config.set('core.float', 0.11)
    atom.config.set('editor.boolean', false)
    atom.config.set('editor.string', 'hey again')
    atom.config.set('editor.object.boolean', false)
    atom.config.set('editor.object.int', 6)
    atom.config.set('editor.object.string', 'hi')

    expect(getValueForId('core.enum')).toBe '6'
    expect(getValueForId('core.int')).toBe '222'
    expect(getValueForId('core.float')).toBe '0.11'
    expect(getValueForId('editor.boolean')).toBeFalsy()
    expect(getValueForId('editor.string')).toBe 'hey again'
    expect(getValueForId('editor.object.boolean')).toBeFalsy()
    expect(getValueForId('editor.object.int')).toBe '6'
    expect(getValueForId('editor.object.string')).toBe 'hi'

    setValueForId('core.enum', '2')
    setValueForId('core.int', 90)
    setValueForId('core.float', 89.2)
    setValueForId('editor.string', "oh hi")
    setValueForId('editor.boolean', true)
    setValueForId('editor.object.boolean', true)
    setValueForId('editor.object.int', 9)
    setValueForId('editor.object.string', 'yo')

    expect(atom.config.get('core.enum')).toBe 2
    expect(atom.config.get('core.int')).toBe 90
    expect(atom.config.get('core.float')).toBe 89.2
    expect(atom.config.get('editor.boolean')).toBe true
    expect(atom.config.get('editor.string')).toBe 'oh hi'
    expect(atom.config.get('editor.object.boolean')).toBe true
    expect(atom.config.get('editor.object.int')).toBe 9
    expect(atom.config.get('editor.object.string')).toBe 'yo'

    setValueForId('core.int', '')
    setValueForId('core.float', '')
    setValueForId('editor.string', '')
    setValueForId('editor.object.int', '')
    setValueForId('editor.object.string', '')

    expect(atom.config.get('core.int')).toBeUndefined()
    expect(atom.config.get('core.float')).toBeUndefined()
    expect(atom.config.get('editor.string')).toBeUndefined()
    expect(atom.config.get('editor.object.int')).toBeUndefined()
    expect(atom.config.get('editor.object.string')).toBeUndefined()

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

    setValueForId('editor.simpleArray', "a, b,")
    expect(atom.config.get('editor.simpleArray')).toEqual ['a', 'b']
    expect(getValueForId('editor.simpleArray')).toBe 'a, b,'

  it "only adds editors for arrays when all the values in the array are strings", ->
    expect(getValueForId('editor.simpleArray')).toBe 'a, b, c'
    expect(getValueForId('editor.complexArray')).toBeUndefined()

    setValueForId('editor.simpleArray', 'a, d')

    expect(atom.config.get('editor.simpleArray')).toEqual ['a', 'd']
    expect(atom.config.get('editor.complexArray')).toEqual ['a', 'b', {c: true}]

  it "shows the package settings notes for core and editor settings", ->
    expect(panel.find('#core-settings-note')).toExist()
    expect(panel.find('#core-settings-note').text()).toContain('Check individual package settings')

    expect(panel.find('#editor-settings-note')).toExist()
    expect(panel.find('#editor-settings-note').text()).toContain('Check language settings')
