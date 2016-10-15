{$$, TextEditorView, ScrollView} = require 'atom-space-pen-views'
_ = require 'underscore-plus'
fuzzaldrin = require 'fuzzaldrin'

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

  # Updates the counts of section when no filter is set
  updateUnfilteredSectionCounts: ->
    for packageType in _.keys(@packages)
      @updateSectionCount(@["#{packageType}PackagesHeader"], @["#{packageType}Count"], @packages[packageType].length())

    @totalPackages.text(@totalPackagesCount())

  # Updates the counts of sections when a filter is set and shows the count of matching packages as well
  updateFilteredSectionCounts: ->
    shownPackages = 0

    for packageType in _.keys(@packages)
      notHidden = @notHiddenCardsLength @["#{packageType}Packages"]
      @updateSectionCount(
        @["#{packageType}PackagesHeader"],
        @["#{packageType}Count"],
        notHidden,
        @packages[packageType].length()
      )
      shownPackages += notHidden

    @totalPackages.text "#{shownPackages}/#{@totalPackagesCount()}"

  resetSectionHasItems: ->
    sections = _.map _.keys(@packages), (section) => @["#{section}PackagesHeader"]
    @resetCollapsibleSections(sections)

  totalPackagesCount: ->
    total = 0
    for packageType in _.keys(@packages)
      total += @packages[packageType].length()
    total

  matchPackages: ->
    filterText = @filterEditor.getModel().getText()
    @filterPackageListByText(filterText)

  filterPackageListByText: (text) ->
    return unless @packages
    for packageType in _.keys(@packages)
      if @itemViews[packageType]
        allViews = @itemViews[packageType].getViews()
        activeViews = @itemViews[packageType].filterViews (pack) ->
          return true if text is ''
          owner = pack.owner()
          filterText = "#{pack.name} #{owner}"
          fuzzaldrin.score(filterText, text) > 0

        for view in allViews when view
          view.find('.package-card').hide().addClass('hidden')
        for view in activeViews when view
          view.find('.package-card').show().removeClass('hidden')

    @updateSectionCounts()

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
