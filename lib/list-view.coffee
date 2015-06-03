module.exports =
class ListView
  # * `list` a {List} object
  # * `container` a jQuery element
  # * `createView` a Function that returns a jQuery element / HTMLElement
  #   * `item` the item to create the view for
  constructor: (@list, @container, @createView) ->
    @views = []
    @viewMap = new WeakMap
    @list.onDidAddItem (item) => @addView(item)
    @list.onDidRemoveItem (item) => @removeView(item)
    @addViews()

  getViews: -> @views

  filterViews: (filterFn) ->
    (@viewMap.get(item) for item in @list.filterItems(filterFn))

  addViews: ->
    for item in @list.getItems()
      @addView(item)
    return

  addView: (item) ->
    view = @createView(item)
    @views.push(view)
    @viewMap.set(item, view)
    @container.prepend(view)

  removeView: (item) ->
    view = @viewMap.get(item)
    if view?
      index = @views.indexOf(view)
      @views.splice(index, 1) if index > -1
      @viewMap.delete(item)
      view.remove()
