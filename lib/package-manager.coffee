{BufferedNodeProcess} = require 'atom'
{Emitter} = require 'emissary'

module.exports =
class PackageManager
  Emitter.includeInto(this)

  runCommand: (args, callback) ->
    command = atom.packages.getApmPath()
    outputLines = []
    stdout = (lines) -> outputLines.push(lines)
    errorLines = []
    stderr = (lines) -> errorLines.push(lines)
    exit = (code) ->
      callback(code, outputLines.join('\n'), errorLines.join('\n'))

    args.push('--no-color')
    new BufferedNodeProcess({command, args, stdout, stderr, exit})

  getAvailable: (callback) ->
    args = ['available', '--json']
    exit = (code, stdout, stderr) =>
      if code is 0
        try
          packages = JSON.parse(stdout) ? []
        catch error
          callback(error)
          return

        callback(null, packages)
      else
        error = new Error("apm available failed with code: #{code}")
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    @runCommand(args, exit)

  install: (pack, callback) ->
    {name, version, theme} = pack
    activateOnSuccess = not theme and not atom.packages.isPackageDisabled(name)
    activateOnFailure = atom.packages.isPackageActive(name)
    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)
    atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)

    args = ['install', "#{name}@#{version}"]
    exit = (code, stdout, stderr) =>
      if code is 0
        if activateOnSuccess
          atom.packages.activatePackage(name)
        else
          atom.packages.loadPackage(name)

        callback?()
        if theme
          @emit 'theme-installed', pack
        else
          @emit 'package-installed', pack
      else
        atom.packages.activatePackage(name) if activateOnFailure
        error = new Error("Installing '#{name}' failed.")
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    @runCommand(args, exit)

  uninstall: (pack, callback) ->
    {name, theme} = pack
    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)

    args = ['uninstall', name]
    exit = (code, stdout, stderr) ->
      if code is 0
        atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)
        callback?()
        if theme
          @emit 'theme-uninstalled', pack
        else
          @emit 'package-uninstalled', pack
      else
        error = new Error("Uninstalling '#{name}' failed.")
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    @runCommand(args, exit)
