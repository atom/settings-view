InstallPanel = require '../lib/install-panel'
PackageManager = require '../lib/package-manager'

describe 'InstallPanel', ->
  beforeEach ->
    @panel = new InstallPanel(new PackageManager)

  describe "when the packages button is clicked", ->
    beforeEach ->
      spyOn(@panel, 'search')
      @panel.searchEditorView.setText('something')

    it "performs a search for the contents of the input", ->
      @panel.searchPackagesButton.click()
      expect(@panel.searchType).toBe 'packages'
      expect(@panel.search).toHaveBeenCalledWith 'something'
      expect(@panel.search.callCount).toBe 1

      @panel.searchPackagesButton.click()
      expect(@panel.searchType).toBe 'packages'
      expect(@panel.search).toHaveBeenCalledWith 'something'
      expect(@panel.search.callCount).toBe 2

  describe "when the themes button is clicked", ->
    beforeEach ->
      spyOn(@panel, 'search')
      @panel.searchEditorView.setText('something')

    it "performs a search for the contents of the input", ->
      @panel.searchThemesButton.click()
      expect(@panel.searchType).toBe 'themes'
      expect(@panel.search.callCount).toBe 1
      expect(@panel.search).toHaveBeenCalledWith 'something'

      @panel.searchThemesButton.click()
      expect(@panel.searchType).toBe 'themes'
      expect(@panel.search.callCount).toBe 2

  describe "when the buttons are toggled", ->
    beforeEach ->
      spyOn(@panel, 'search')
      @panel.searchEditorView.setText('something')

    it "performs a search for the contents of the input", ->
      @panel.searchThemesButton.click()
      expect(@panel.searchType).toBe 'themes'
      expect(@panel.search.callCount).toBe 1
      expect(@panel.search).toHaveBeenCalledWith 'something'

      @panel.searchPackagesButton.click()
      expect(@panel.searchType).toBe 'packages'
      expect(@panel.search.callCount).toBe 2

      @panel.searchThemesButton.click()
      expect(@panel.searchType).toBe 'themes'
      expect(@panel.search.callCount).toBe 3
