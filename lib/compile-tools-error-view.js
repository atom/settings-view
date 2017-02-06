/** @babel */
/** @jsx etch.dom */

import etch from 'etch'

export default class CompileToolsErrorView {
  constructor () {
    etch.initialize(this)
  }

  render () {
    return (
      <div>
        <div className='icon icon-alert compile-tools-heading compile-tools-message'>Compiler tools not found</div>
        <div className='compile-tools-message'>Packages that depend on modules that contain C/C++ code will fail to install.</div>
        <div className='compile-tools-message'>
          <span>Read </span>
          <a className='link' href='https://atom.io/docs/latest/build-instructions/windows'>here</a>
          <span> for instructions on installing Python and Visual Studio.</span>
        </div>
        <div className='compile-tools-message'>
          <span>Run </span>
          <code className='alert-danger'>apm install --check</code>
          <span> after installing to test compiling a native module.</span>
        </div>
      </div>
    )
  }
}
