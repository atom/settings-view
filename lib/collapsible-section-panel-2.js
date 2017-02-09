/** @babel */

import {CompositeDisposable, Disposable} from 'atom'

export default class CollapsibleSectionPanel {
  notHiddenCardsLength (sectionElement) {
    return sectionElement.querySelectorAll('.package-card:not(.hidden)').length
  }

  updateSectionCount (headerElement, countElement, packageCount, totalCount) {
    if (totalCount) {
      countElement.textContent = `${packageCount}/${totalCount}`
    } else {
      countElement.textContent = packageCount
    }

    if (packageCount > 0) {
      headerElement.classList.add("has-items")
    }
  }

  updateSectionCounts () {
    this.resetSectionHasItems()

    filterText = this.filterEditor.getText()
    if (filterText === '') {
      this.updateUnfilteredSectionCounts()
    } else {
      this.updateFilteredSectionCounts()
    }
  }

  handleEvents () {
    const disposables = new CompositeDisposable()
    const handler = () => {
      const target = e.target.closest('.sub-section .has-items')
      if (target) {
        target.parentNode.classList.toggle('collapsed')
      }
    }
    disposables.add(new Disposable(() => this.element.removeEventListener('click', handler)))
    disposables.add(atom.commands.add(this.element, {
      'core:move-up': () => { this.scrollUp() },
      'core:move-down': () => { this.scrollDown() },
      'core:page-up': () => { this.pageUp() },
      'core:page-down': () => { this.pageDown() },
      'core:move-to-top': () => { this.scrollToTop() },
      'core:move-to-bottom': () => { this.scrollToBottom() }
    }))
    return disposables
  }

  resetCollapsibleSections (headerSections) {
    for (const headerSection of headerSections) {
      this.resetCollapsibleSection(headerSection)
    }
  }

  resetCollapsibleSection (headerSection) {
    headerSection.classList.remove('has-items')
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
