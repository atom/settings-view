{$} = require 'atom-space-pen-views'
InstallPanel = require '../lib/install-panel'
PackageManager = require '../lib/package-manager'
Q = require 'q'

describe 'InstallPanel', ->
  beforeEach ->
    @panel = new InstallPanel(new PackageManager)

  it 'Should hide search message at initialize', ->
    expect(@panel.searchMessage.css('display')).toBe('none')

  it 'Should search after pressing enter in search input field', ->
    spyOn(@panel, 'performSearch')
    event = $.Event('keyup')
    event.which = 13
    @panel.searchEditorView.val('hello').trigger(event)
    expect(@panel.performSearch).toHaveBeenCalled()
