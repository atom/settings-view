_ = require 'underscore-plus'
{Emitter} = require 'atom'

module.exports =
class List
  #
  #  * `key` {String} property to identify items by
  #
  constructor: (@key) ->
    @items = []
    @emitter = new Emitter

  getItems: -> @items

  filterItems: (filterFn) ->
    (item for item in @items when filterFn(item))

  keyForItem: (item) ->
    item[@key]

  setItems: (items) ->
    items = items.slice(0)
    setToAdd = difference(items, @items, @key)
    setToRemove = difference(@items, items, @key)

    @items = items

    for item in setToAdd
      @emitter.emit('did-add-item', item)
    for item in setToRemove
      @emitter.emit('did-remove-item', item)

    if setToAdd.length > 0 or setToRemove.length > 0
      @emitter.emit('did-change')

  onDidAddItem: (callback) ->
    @emitter.on('did-add-item', callback)

  onDidRemoveItem: (callback) ->
    @emitter.on('did-remove-item', callback)

  onDidChange: (callback) ->
    @emitter.on('did-change', callback)

  length: ->
    @items.length

  sort: (sortFn) ->
    @items.sort sortFn

difference = (array1, array2, key) ->
  obj1 = {}
  for item in array1
    obj1[item[key]] = item

  obj2 = {}
  for item in array2
    obj2[item[key]] = item

  diff = []
  for k, v of obj1
    diff.push(v) unless obj2[k]?
  diff
