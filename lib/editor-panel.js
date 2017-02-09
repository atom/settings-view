/** @babel */
/** @jsx etch.dom */

import {CompositeDisposable, Disposable} from 'atom'
import etch from 'etch'
import SettingsPanel from './settings-panel-2'

export default class EditorPanel {
  constructor () {
    etch.initialize(this)
    this.subscriptions = new CompositeDisposable()
    this.subscriptions.add(atom.commands.add(this.element, {
      'core:move-up': () => { this.scrollUp() },
      'core:move-down': () => { this.scrollDown() },
      'core:page-up': () => { this.pageUp() },
      'core:page-down': () => { this.pageDown() },
      'core:move-to-top': () => { this.scrollToTop() },
      'core:move-to-bottom': () => { this.scrollToBottom() }
    }))

    const clickHandler = (event) => {
      const target = event.target.closest('.packages-open')
      if (target) {
        atom.workspace.open('atom://config/packages')
      }
    }
    this.element.addEventListener('click', clickHandler)
    this.subscriptions.add(new Disposable(() => this.element.removeEventListener('click', clickHandler)))
  }

  destroy () {
    this.subscriptions.dispose()
    return etch.destroy(this)
  }

  update () {}

  render () {
    return (
      <div tabIndex='0' className='panels-item'>
        <SettingsPanel
          namespace='editor'
          icon='code'
          note={`<div class="text icon icon-question" id="editor-settings-note" tabindex="-1">These settings are related to text editing. Some of these can be overriden on a per-language basis. Check language settings by clicking its package card in the <a class="link packages-open">Packages list</a>.</div>`} />
      </div>
    )
  }

  focus () {
    this.element.focus()
  }

  show () {
    this.element.style.display = ''
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
