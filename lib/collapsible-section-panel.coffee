{$$, TextEditorView, ScrollView} = require 'atom-space-pen-views'

module.exports =
class CollapsibleSectionPanel extends ScrollView
  notHiddenCardsLength: (sectionElement) ->
    sectionElement.find('.package-card:not(.hidden)').length

  updateSectionCount: (headerElement, countElement, packageCount, totalCount) ->
    if totalCount is undefined
      countElement.text packageCount
    else
      countElement.text "#{packageCount}/#{totalCount}"

    headerElement.addClass("has-items") if packageCount > 0

  updateSectionCounts: ->
    @resetSectionHasItems()

    filterText = @filterEditor.getModel().getText()
    if filterText is ''
      @updateUnfilteredSectionCounts()
    else
      @updateFilteredSectionCounts()

  handleEvents: ->
    @on 'click', '.sub-section .has-items', (e) ->
      e.currentTarget.parentNode.classList.toggle('collapsed')

  resetCollapsibleSections: (headerSections) ->
    @resetCollapsibleSection headerSection for headerSection in headerSections

  resetCollapsibleSection: (headerSection) ->
    headerSection.removeClass('has-items')
