{$} = require 'atom-space-pen-views'
List = require '../lib/list'
ListView = require '../lib/list-view'

describe 'ListView', ->
  [list, view, container, containerEl] = []

  beforeEach ->
    list = new List('name')
    container = $('<div/>')
    containerEl = container[0]
    view = new ListView list, container, (item) ->
      element = $('<div/>')
      element.addClass(item.name)
      element.text("#{item.name}|#{item.text}")
      element

  it 'updates the list when the items are changed', ->
    expect(containerEl.childNodes.length).toBe 0

    items = [{name: 'one', text: 'a'}, {name: 'two', text: 'b'}]
    list.setItems(items)
    expect(containerEl.childNodes.length).toBe 2
    expect(containerEl.querySelector('.one').innerText).toBe 'one|a'
    expect(containerEl.querySelector('.two').innerText).toBe 'two|b'

    items = [{name: 'three', text: 'c'}, {name: 'two', text: 'b'}]
    list.setItems(items)
    expect(containerEl.childNodes.length).toBe 2
    expect(containerEl.querySelector('.one')).not.toExist()
    expect(containerEl.querySelector('.two').innerText).toBe 'two|b'
    expect(containerEl.querySelector('.three').innerText).toBe 'three|c'

  it 'filters views', ->
    items = [
      {name: 'one', text: '', filterText: 'x'},
      {name: 'two', text: '', filterText: 'y'}
      {name: 'three', text: '', filterText: 'x'}
      {name: 'four', text: '', filterText: 'z'}
    ]

    list.setItems(items)
    views = view.filterViews (item) ->
      item.filterText is 'x'

    expect(views).toHaveLength 2
    expect(views[0].text()).toBe 'one|'
    expect(views[1].text()).toBe 'three|'

  it 'filters views after an update', ->
    items = [
      {name: 'one', text: '', filterText: 'x'},
      {name: 'two', text: '', filterText: 'y'}
      {name: 'three', text: '', filterText: 'x'}
      {name: 'four', text: '', filterText: 'z'}
    ]
    list.setItems(items)

    items = [
      {name: 'one', text: '', filterText: 'x'},
      {name: 'two', text: '', filterText: 'y'}
      {name: 'three', text: '', filterText: 'x'}
      {name: 'four', text: '', filterText: 'z'}
    ]
    list.setItems(items)
    views = view.filterViews (item) ->
      item.filterText is 'x'

    expect(views).toHaveLength 2
    expect(views[0].text()).toBe 'one|'
    expect(views[1].text()).toBe 'three|'
