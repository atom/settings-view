let SettingsView = null
let settingsView = null

let statusView = null

const {CompositeDisposable} = require('atom')

const PackageManager = require('./package-manager')
let packageManager = null

const SnippetsProvider = {
  getSnippets() { return atom.config.scopedSettingsStore.propertySets }
}

const CONFIG_URI = 'atom://config'

module.exports = {
  handleURI(parsed) {
    switch (parsed.pathname) {
      case '/show-package': this.showPackage(parsed.query.package)
    }
  },

  showPackage(packageName) {
    atom.workspace.open(`atom://config/packages/${packageName}`)
  },

  activate() {
    this.disposables = new CompositeDisposable()

    this.disposables.add(atom.workspace.addOpener(uri => {
      if (uri.startsWith(CONFIG_URI)) {
        if (settingsView == null || settingsView.destroyed) {
          settingsView = this.createSettingsView({uri})
        } else {
          const pane = atom.workspace.paneForItem(settingsView)
          if (pane) pane.activate()
        }

        settingsView.showPanelForURI(uri)
        return settingsView
      }
    }))

    this.disposables.add(atom.commands.add('atom-workspace', {
      'settings-view:open'() { atom.workspace.open(CONFIG_URI) },
      'settings-view:core'() { atom.workspace.open(`${CONFIG_URI}/core`) },
      'settings-view:editor'() { atom.workspace.open(`${CONFIG_URI}/editor`) },
      'settings-view:show-keybindings'() { atom.workspace.open(`${CONFIG_URI}/keybindings`) },
      'settings-view:change-themes'() { atom.workspace.open(`${CONFIG_URI}/themes`) },
      'settings-view:install-packages-and-themes'() { atom.workspace.open(`${CONFIG_URI}/install`) },
      'settings-view:view-installed-themes'() { atom.workspace.open(`${CONFIG_URI}/themes`) },
      'settings-view:uninstall-themes'() { atom.workspace.open(`${CONFIG_URI}/themes`) },
      'settings-view:view-installed-packages'() { atom.workspace.open(`${CONFIG_URI}/packages`) },
      'settings-view:uninstall-packages'() { atom.workspace.open(`${CONFIG_URI}/packages`) },
      'settings-view:check-for-package-updates'() { atom.workspace.open(`${CONFIG_URI}/updates`) }
    }))

    if (process.platform === 'win32' && require('atom').WinShell != null) {
      this.disposables.add(atom.commands.add('atom-workspace', {'settings-view:system'() { atom.workspace.open(`${CONFIG_URI}/system`) }}))
    }

    if (!localStorage.getItem('hasSeenDeprecatedNotification')) {
      if (packageManager == null) packageManager = new PackageManager()
      packageManager.getInstalled().then(packages => {
        if (packages.user && packages.user.length) this.showDeprecatedNotification(packages)
      })
    }
  },

  deactivate() {
    if (this.disposables) this.disposables.dispose()
    if (settingsView) settingsView.destroy()
    if (packageManager) packageManager.destroy()
    if (statusView) statusView.destroy()
    this.disposables = null
    settingsView = null
    packageManager = null
    statusView = null
  },

  consumeStatusBar(statusBar) {
    if (packageManager == null) packageManager = new PackageManager()
    packageManager.getOutdated().then(updates => {
      if (packageManager) {
        const PackageUpdatesStatusView = require('./package-updates-status-view')
        statusView = new PackageUpdatesStatusView()
        statusView.initialize(statusBar, packageManager, updates)
      }
    })
  },

  consumeSnippets(snippets) {
    if (typeof snippets.getUnparsedSnippets === 'function') {
      SnippetsProvider.getSnippets = snippets.getUnparsedSnippets.bind(snippets)
    }
    if (typeof snippets.getUserSnippetsPath === 'function') {
      SnippetsProvider.getUserSnippetsPath = snippets.getUserSnippetsPath.bind(snippets)
    }
  },

  createSettingsView(params) {
    if (SettingsView == null) SettingsView = require('./settings-view')
    if (packageManager == null) packageManager = new PackageManager()
    params.packageManager = packageManager
    params.snippetsProvider = SnippetsProvider
    settingsView = new SettingsView(params)
    return settingsView
  },

  showDeprecatedNotification(packages) {
    localStorage.setItem('hasSeenDeprecatedNotification', true)

    const deprecatedPackages = packages.user.filter(({name, version}) => atom.packages.isDeprecatedPackage(name, version))
    if (!deprecatedPackages.length) return

    let were = 'were'
    let have = 'have'
    let packageText = 'packages'
    if (packages.length === 1) {
      packageText = 'package'
      were = 'was'
      have = 'has'
    }

    const notification = atom.notifications.addWarning(`${deprecatedPackages.length} ${packageText} ${have} deprecations and ${were} not loaded.`, {
      description: 'This message will show only one time. Deprecated packages can be viewed in the settings view.',
      detail: (deprecatedPackages.map(pack => pack.name)).join(', '),
      dismissable: true,
      buttons: [{
        text: 'View Deprecated Packages',
        onDidClick() {
          atom.commands.dispatch(atom.views.getView(atom.workspace), 'settings-view:view-installed-packages')
          notification.dismiss()
        }
      }]
    })
  }
}
