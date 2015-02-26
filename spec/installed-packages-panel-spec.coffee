path = require 'path'

fs = require 'fs-plus'
InstalledPackagesPanel = require '../lib/installed-packages-panel'
PackageManager = require '../lib/package-manager'
Q = require 'q'

describe 'InstalledPackagesPanel', ->
  beforeEach ->
    @packageManager = new PackageManager
    @installed = JSON.parse fs.readFileSync(path.join(__dirname, 'fixtures', 'installed.json'))
    spyOn(@packageManager, 'getInstalled').andReturn Q(@installed)
    @panel = new InstalledPackagesPanel(@packageManager)

  it 'shows packages', ->
    waitsFor ->
      @packageManager.getInstalled.callCount is 1 and @panel.communityCount.text().indexOf('…') < 0
    runs ->
      expect(@panel.communityCount.text().trim()).toBe '1'
      expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(@panel.coreCount.text().trim()).toBe '1'
      expect(@panel.corePackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(@panel.devCount.text().trim()).toBe '1'
      expect(@panel.devPackages.find('.package-card:not(.hidden)').length).toBe 1

  it 'filters packages by name', ->
    waitsFor ->
      @packageManager.getInstalled.callCount is 1 and @panel.communityCount.text().indexOf('…') < 0

    runs ->
      @panel.filterEditor.getModel().setText('user-')
      window.advanceClock(@panel.filterEditor.getModel().getBuffer().stoppedChangingDelay)
      expect(@panel.communityCount.text().trim()).toBe '1/1'
      expect(@panel.communityPackages.find('.package-card:not(.hidden)').length).toBe 1

      expect(@panel.coreCount.text().trim()).toBe '0/1'
      expect(@panel.corePackages.find('.package-card:not(.hidden)').length).toBe 0

      expect(@panel.devCount.text().trim()).toBe '0/1'
      expect(@panel.devPackages.find('.package-card:not(.hidden)').length).toBe 0
