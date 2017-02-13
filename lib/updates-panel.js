/** @babel */
/** @jsx etch.dom */

import {CompositeDisposable} from 'atom'
import etch from 'etch'

import ErrorView from './error-view'
import PackageCard from './package-card'

export default class UpdatesPanel {
  constructor (settingsView, packageManager) {
    this.settingsView = settingsView
    this.packageManager = packageManager
    this.disposables = new CompositeDisposable()
    this.updatingPackages = []
    this.packageCards = []

    etch.initialize(this)

    this.refs.updateAllButton.style.display = 'none'
    this.checkForUpdates()

    this.disposables.add(atom.commands.add(this.element, {
      'core:move-up': () => { this.scrollUp() },
      'core:move-down': () => { this.scrollDown() },
      'core:page-up': () => { this.pageUp() },
      'core:page-down': () => { this.pageDown() },
      'core:move-to-top': () => { this.scrollToTop() },
      'core:move-to-bottom': () => { this.scrollToBottom() }
    }))

    this.disposables.add(this.packageManager.on('package-updating theme-updating', ({pack, error}) => {
      this.refs.checkButton.disabled = true
      this.updatingPackages.push(pack)
    }))

    this.disposables.add(
      this.packageManager.on('package-updated theme-updated package-update-failed theme-update-failed', ({pack, error}) => {
        if (error != null) {
          this.refs.updateErrors.appendChild(new ErrorView(this.packageManager, error).element)
        }

        for (let i = 0; i < this.updatingPackages.length; i++) {
          const update = this.updatingPackages[i]
          if (update.name === pack.name) {
            this.updatingPackages.splice(i, 1)
          }
        }

        if (!this.updatingPackages.length) {
          this.refs.checkButton.disabled = false
        }
      })
    )
  }

  destroy () {
    this.clearPackageCards()
    this.disposables.dispose()
    return etch.destroy(this)
  }

  update () {}

  render () {
    return (
      <div tabIndex='0' className='panels-item'>
        <section className='section packages'>
          <div className='section-container updates-container'>
            <h1 className='section-heading icon icon-cloud-download'>
              Available Updates
              <button
                ref='updateAllButton'
                className='pull-right update-all-button btn btn-primary'
                onclick={() => { this.updateAll() }}>Update All</button>
              <button
                ref='checkButton'
                className='pull-right update-all-button btn btn'
                onclick={() => { debugger; this.checkForUpdates(true) }}>Check for Updates</button>
            </h1>

            <div ref='updateErrors'></div>
            <div ref='checkingMessage' className='alert alert-info icon icon-hourglass'>{`Checking for updates\u2026`}</div>
            <div ref='noUpdatesMessage' className='alert alert-info icon icon-heart'>All of your installed packages are up to date!</div>
            <div ref='updatesContainer' className='container package-container'></div>
          </div>
        </section>
      </div>
    )
  }

  focus () {
    this.element.focus()
  }

  show () {
    this.element.style.display = ''
  }

  beforeShow (opts) {
    if (opts && opts.back) {
      this.refs.breadcrumb.textContent = opts.back
      this.refs.breadcrumb.onclick = () => { this.settingsView.showPanel(opts.back) }
    }

    if (opts && opts.updates) {
      this.availableUpdates = opts.updates
      this.addUpdateViews()
    } else {
      this.availableUpdates = []
      this.clearPackageCards()
      this.checkForUpdates()
    }
  }

  // Check for updates and display them
  async checkForUpdates (clearCache) {
    this.refs.noUpdatesMessage.style.display = 'none'
    this.refs.updateAllButton.disabled = true
    this.refs.checkButton.disabled = true
    this.refs.checkingMessage.style.display = ''

    try {
      this.availableUpdates = await this.packageManager.getOutdated(clearCache)
      this.refs.checkButton.disabled = false
      this.addUpdateViews()
    } catch (error) {
      this.refs.checkButton.disabled = false
      this.refs.checkingMessage.style.display = 'none'
      this.refs.updateErrors.appendChild(new ErrorView(this.packageManager, error).element)
    }
  }

  addUpdateViews () {
    if (this.availableUpdates.length > 0) {
      this.refs.updateAllButton.style.display = ''
      this.refs.updateAllButton.disabled = false
    }
    this.refs.checkingMessage.style.display = 'none'
    this.clearPackageCards()
    if (this.availableUpdates.length === 0) {
      this.refs.noUpdatesMessage.style.display = ''
    }

    for (const pack of this.availableUpdates) {
      const packageCard = new PackageCard(pack, this.packageManager, {back: 'Updates'})
      this.refs.updatesContainer.appendChild(packageCard.element)
      this.packageCards.push(packageCard)
    }
  }

  updateAll () {
    this.refs.checkButton.disabled = true
    this.refs.updateAllButton.disabled = true

    let successfulUpdatesCount = 0
    let remainingPackagesCount = this.packageCards.length
    let totalUpdatesCount = this.packageCards.length // This value doesn't change unlike remainingPackagesCount

    const notifyIfDone = () => {
      if (remainingPackagesCount === 0) {
        if (successfulUpdatesCount > 0) {
          let pluralizedPackages = 'package'
          if (successfulUpdatesCount > 1) {
            pluralizedPackages += 's'
          }
          const message = `Restart Atom to complete the update of ${successfulUpdatesCount} ${pluralizedPackages}.`

          const buttons = [{
            text: 'Restart',
            onDidClick() { return atom.restartApplication() }
          }]
          atom.notifications.addSuccess(message, {dismissable: true, buttons})
        }

        if (successfulUpdatesCount === totalUpdatesCount) {
          this.refs.checkButton.disabled = false
          this.refs.updateAllButton.style.display = 'none'
        } else { // Some updates failed
          this.refs.checkButton.disabled = false
          this.refs.updateAllButton.disabled = false
        }
      }
    }

    const onUpdateResolved = function() {
      remainingPackagesCount--
      successfulUpdatesCount++
      notifyIfDone()
    }

    const onUpdateRejected = function() {
      remainingPackagesCount--
      notifyIfDone()
    }

    for (const packageCard of this.packageCards) {
      if (!this.updatingPackages.includes(packageCard.pack)) {
        packageCard.update().then(onUpdateResolved, onUpdateRejected)
      } else {
        remainingPackagesCount--
        totalUpdatesCount--
      }
    }
  }

  clearPackageCards () {
    let packageCard = null
    while (packageCard = this.packageCards.pop()) {
      packageCard.destroy()
    }
  }

  scrollUp () {
    this.element.scrollTop -= document.body.offsetHeight / 20
  }

  scrollDown () {
    this.element.scrollTop += document.body.offsetHeight / 20
  }

  pageUp () {
    this.element.scrollTop -= this.element.offsetHeight
  }

  pageDown () {
    this.element.scrollTop += this.element.offsetHeight
  }

  scrollToTop () {
    this.element.scrollTop = 0
  }

  scrollToBottom () {
    this.element.scrollTop = this.element.scrollHeight
  }
}