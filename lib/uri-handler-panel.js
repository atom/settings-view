/** @babel */
/** @jsx etch.dom */

import {CompositeDisposable} from 'atom'
import etch from 'etch'

function isSupported () {
  return ['win32', 'darwin'].includes(process.platform)
}

function isDefaultProtocolClient () {
  return require('electron').remote.app.isDefaultProtocolClient('atom', process.execPath, ['--url-handler'])
}

function setAsDefaultProtocolClient () {
  // This Electron API is only available on Windows and macOS. There might be some
  // hacks to make it work on Linux; see https://github.com/electron/electron/issues/6440
  return isSupported() && require('electron').remote.app.setAsDefaultProtocolClient('atom', process.execPath, ['--url-handler'])
}

export default class UriHandlerPanel {
  constructor () {
    this.handleChange = this.handleChange.bind(this)
    this.handleBecomeProtocolClient = this.handleBecomeProtocolClient.bind(this)
    this.isDefaultProtocolClient = isDefaultProtocolClient()
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
  }

  destroy () {
    this.subscriptions.dispose()
    return etch.destroy(this)
  }

  update () {}

  render () {
    const schema = atom.config.getSchema('core.uriHandlerRegistration')

    return (
      <div className='panels-item' tabIndex='0'>
        <form className='general-panel section'>
          <div className='settings-panel'>
            <div className='section-container'>
              <div className='block section-heading icon icon-device-desktop'>URI Handling</div>
              <div className='text icon icon-question'>These settings determine how Atom handles atom:// URIs.</div>
              <div className='section-body'>
                <div className='control-group'>
                  <div className='controls'>
                    <label className='control-label'>
                      <div className='setting-title'>URI Handler Registration</div>
                      <div className='setting-description'>
                        {this.renderRegistrationDescription()}
                      </div>
                    </label>
                    <button
                      className='btn btn-primary'
                      disabled={!isSupported() || this.isDefaultProtocolClient}
                      style={{fontSize: '1.25em', display: 'block'}}
                      onClick={this.handleBecomeProtocolClient}
                    >
                      Register as atom:// protocol handler
                    </button>
                  </div>
                </div>

                <div className='control-group'>
                  <div className='controls'>
                    <label className='control-label'>
                      <div className='setting-title'>Default Registration</div>
                      <div className='setting-description'>
                        {schema.description}
                      </div>
                    </label>
                    <select
                      id='core.uriHandlerRegistration'
                      className='form-control'
                      onChange={this.handleChange}
                      value={atom.config.get('core.uriHandlerRegistration')}
                    >
                      {schema.enum.map(({description, value}) => (
                        <option value={value}>{description}</option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </form>
      </div>
    )
  }

  renderRegistrationDescription () {
    if (this.isDefaultProtocolClient) {
      return 'Atom is already the default handler for atom:// URIs.'
    } else if (isSupported()) {
      return 'Register Atom as the default handler for atom:// URIs.'
    } else {
      return 'Registration as the default handler for atom:// URIs is only supported on Windows and macOS.'
    }
  }

  handleChange (evt) {
    atom.config.set('core.uriHandlerRegistration', evt.target.value)
  }

  handleBecomeProtocolClient (evt) {
    evt.preventDefault()
    if (setAsDefaultProtocolClient()) {
      this.isDefaultProtocolClient = isDefaultProtocolClient()
      etch.update(this)
    } else {
      atom.notifications.addError('Could not become default protocol client')
    }
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
