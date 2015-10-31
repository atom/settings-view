fuzzaldrin = require 'fuzzaldrin'
{$$, ScrollView} = require 'atom-space-pen-views'
PackageCard = require './package-card'
{packageComparatorAscending} = require './utils'

module.exports =
class CollapsibleSectionPanel extends ScrollView
  focus: ->
    @filterEditor.focus()

  dispose: ->
    @disposables.dispose()

  sortPackages: (packages) ->
    for pkg of packages
      packages[pkg].sort(packageComparatorAscending)
    packages

  filterPackageListByTextAndType: (text, packageTypes) ->
    return unless @packages

    for packageType in packageTypes
      allViews = @itemViews[packageType].getViews()
      activeViews = @itemViews[packageType].filterViews (pack) ->
        return true if text is ''
        owner = pack.owner ? ownerFromRepository(pack.repository)
        filterText = "#{pack.name} #{owner}"
        fuzzaldrin.score(filterText, text) > 0

      for view in allViews when view
        view.find('.package-card').hide().addClass('hidden')
      for view in activeViews when view
        view.find('.package-card').show().removeClass('hidden')

    @updateSectionCounts()

  createPackageCard: (pack, back) ->
    packageRow = $$ -> @div class: 'row'
    packView = new PackageCard(pack, @packageManager, {back: back})
    packageRow.append(packView)
    packageRow

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

  matchPackages: ->
    filterText = @filterEditor.getModel().getText()
    @filterPackageListByText(filterText)
