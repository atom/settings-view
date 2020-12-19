# Settings View package
[![macOS Build Status](https://travis-ci.org/atom/settings-view.svg?branch=master)](https://travis-ci.org/atom/settings-view) [![Windows Build Status](https://ci.appveyor.com/api/projects/status/hatgxg6k2g3grafq/branch/master?svg=true)](https://ci.appveyor.com/project/Atom/settings-view/branch/master) [![Dependency Status](https://david-dm.org/atom/settings-view.svg)](https://david-dm.org/atom/settings-view)

Edit core configuration settings, install and configure packages, and change themes from within Atom.

![Settings View](https://cloud.githubusercontent.com/assets/118951/16886698/b0ca5fae-4a8a-11e6-8afc-2c03fda4618c.PNG)

## Usage
You can open the Settings View by navigating to _Edit > Preferences_ (Linux), _Atom > Preferences_ (macOS), or _File > Settings_ (Windows).

In order to install new packages and themes, click on the _Install_ section on the left-hand side.
Once installed, community packages/themes and their settings are housed within their respective section.
All packages/themes that have updates will be listed under the _Updates_ section. Finally, all keybindings (including ones that community packages have added) are available in the _Keybindings_ section.

Want to learn more? Check out the [Getting Started: Atom Basics](http://flight-manual.atom.io/getting-started/sections/atom-basics/#settings-and-preferences) and [Using Atom: Atom Packages](http://flight-manual.atom.io/using-atom/sections/atom-packages) sections in the Atom Flight Manual.

### Commands and Keybindings
All of the following commands are under the `atom-workspace` selector.

|Command|Description|Keybinding (Linux)|Keybinding (macOS)|Keybinding (Windows)|
|-------|-----------|------------------|-----------------|--------------------|
|`settings-view:open`|Opens the Settings View|<kbd>ctrl-,</kbd>|<kbd>cmd-,</kbd>|<kbd>ctrl-,</kbd>|
|`settings-view:core`|Opens the _Core_ section of the Settings View|
|`settings-view:editor`|Opens the _Editor_ section of the Settings View|
|`settings-view:system`|Opens the _System_ section of the Settings View (Windows)|
|`settings-view:show-keybindings`|Opens the _Keybindings_ section of the Settings View|
|`settings-view:uninstall-packages`|Opens the _Packages_ section of the Settings View|
|`settings-view:change-themes`|Opens the _Themes_ section of the Settings View|
|`settings-view:uninstall-themes`|Opens the _Themes_ section of the Settings View|
|`settings-view:check-for-updates`|Opens the _Updates_ section of the Settings View|
|`settings-view:install-packages-and-themes`|Opens the _Install_ section of the Settings View|
Custom keybindings can be added by referencing the above commands.  To learn more, visit the [Using Atom: Basic Customization](http://flight-manual.atom.io/using-atom/sections/basic-customization/#customizing-keybindings) or [Behind Atom: Keymaps In-Depth](http://flight-manual.atom.io/behind-atom/sections/keymaps-in-depth) sections in the flight manual.

## Customize
The Settings View package uses the `ui-variables` to match a theme's color scheme. You can still customize the UI in your `styles.less` file. For example:

```less
// Change the color of the titles
.settings-view .section .section-heading {
  color: white;
}

// Change the font size of the setting descriptions
.settings-view .setting-description {
  font-size: 13px;
}
```

Use the [developer tools](http://flight-manual.atom.io/hacking-atom/sections/creating-a-theme/#developer-tools) to find more selectors.

## Contributing
Always feel free to help out!  Whether it's [filing bugs and feature requests](https://github.com/atom/settings-view/issues/new) or working on some of the [open issues](https://github.com/atom/settings-view/issues), Atom's [contributing guide](https://github.com/atom/atom/blob/master/CONTRIBUTING.md) will help get you started while the [guide for contributing to packages](https://github.com/atom/atom/blob/master/docs/contributing-to-packages.md) has some extra information.

## License
MIT License.  See [the license](LICENSE.md) for more details.
