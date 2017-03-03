/** @babel */
/** @jsx etch.dom */

import path from 'path'
import _ from 'underscore-plus'
import etch from 'etch'

// View to display the snippets that a package has registered.
export default class PackageSnippetsView {
  constructor (packagePath, snippetsProvider) {
    this.snippetsProvider = snippetsProvider
    this.packagePath = path.join(packagePath, path.sep)
    etch.initialize(this)
    this.element.style.display = 'none'
    this.addSnippets()
  }

  destroy () {
    return etch.destroy(this)
  }

  update () {}

  render () {
    return (
      <section className='section'>
        <div className='section-heading icon icon-code'>Snippets</div>
        <table className='package-snippets-table table native-key-bindings text' tabIndex={-1}>
          <thead>
            <tr>
              <th>Trigger</th>
              <th>Name</th>
              <th>Body</th>
            </tr>
          </thead>
          <tbody ref='snippets'></tbody>
        </table>
      </section>
    )
  }

  getSnippetProperties () {
    const packageProperties = {}
    for (const {name, properties} of this.snippetsProvider.getSnippets()) {
      if (name && name.indexOf && name.indexOf(this.packagePath) === 0) {
        const object = properties.snippets != null ? properties.snippets : {}
        for (let key in object) {
          const snippet = object[key]
          if (snippet != null) {
            if (packageProperties[key] == null) {
              packageProperties[name] = snippet
            }
          }
        }
      }
    }

    return _.values(packageProperties).sort((snippet1, snippet2) => {
      const prefix1 = snippet1.prefix != null ? snippet1.prefix : ''
      const prefix2 = snippet2.prefix != null ? snippet2.prefix : ''
      return prefix1.localeCompare(prefix2)
    })
  }

  getSnippets (callback) {
    const snippetsPackage = atom.packages.getLoadedPackage('snippets')
    const snippetsModule = snippetsPackage ? snippetsPackage.mainModule : null
    if (snippetsModule) {
      if (snippetsModule.loaded) {
        callback(this.getSnippetProperties())
      } else {
        snippetsModule.onDidLoadSnippets(() => callback(this.getSnippetProperties()))
      }
    } else {
      callback([])
    }
  }

  addSnippets () {
    this.getSnippets((snippets) => {
      this.refs.snippets.innerHTML = ''

      for (let {body, bodyText, name, prefix} of snippets) {
        if (name == null) {
          name = ''
        }

        if (prefix == null) {
          prefix = ''
        }

        if (body == null) {
          body = bodyText
        }

        if (body) {
          body = body.replace(/\t/g, '\\t').replace(/\n/g, '\\n')
        } else {
          body = ''
        }

        const row = document.createElement('tr')

        const prefixTd = document.createElement('td')
        prefixTd.classList.add('snippet-prefix')
        prefixTd.textContent = prefix
        row.appendChild(prefixTd)

        const nameTd = document.createElement('td')
        nameTd.textContent = name
        row.appendChild(nameTd)

        const bodyTd = document.createElement('td')
        bodyTd.classList.add('snippet-body')
        bodyTd.textContent = body
        row.appendChild(bodyTd)

        this.refs.snippets.appendChild(row)
      }

      if (this.refs.snippets.children.length > 0) {
        this.refs.snippets.style.display = ''
      } else {
        this.refs.snippets.style.display = 'none'
      }
    })
  }
}
