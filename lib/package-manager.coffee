{BufferedNodeProcess} = require 'atom'
{Emitter} = require 'emissary'
roaster = require 'roaster'
async = require 'async'

module.exports =
class PackageManager
  Emitter.includeInto(this)

  constructor: ->
    @apmCommand = atom.packages.getApmPath()

  renderMarkdownInMetadata: (packages, callback) ->
    queue = async.queue (pack, callback) ->
      operations = []
      if pack.description
        operations.push (callback) ->
          roaster pack.description, {}, (error, html) ->
            pack.descriptionHtml = html
            callback()
      if pack.readme
        operations.push (callback) ->
          roaster pack.readme, {}, (error, html) ->
            pack.readmeHtml = html
            callback()
      async.waterfall(operations, callback)
    queue.push(pack) for pack in packages
    queue.drain = callback

  runCommand: (command, args, callback) ->
    outputLines = []
    stdout = (lines) -> outputLines.push(lines)
    errorLines = []
    stderr = (lines) -> errorLines.push(lines)
    exit = (code) ->
      callback(code, outputLines.join('\n'), errorLines.join('\n'))

    new BufferedNodeProcess({command, args, stdout, stderr, exit})

  getAvailable: (callback) ->
    command = @apmCommand
    args = ['available', '--json', '--no-color']
    exit = (code, stdout, stderr) =>
      if code is 0
        try
          packages = JSON.parse(outputLines.join('\n')) ? []
        catch error
          callback(error)
          return

        if packages.length > 0
          @renderMarkdownInMetadata packages, -> callback(null, packages)
        else
          callback(null, packages)
      else
        error = new Error("apm available failed with code: #{code}")
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    @runCommand(command, args, exit)

  install: (pack, callback) ->
    {name, version, theme} = pack
    activateOnSuccess = not theme and not atom.packages.isPackageDisabled(name)
    activateOnFailure = atom.packages.isPackageActive(name)
    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)
    atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)

    command = @apmCommand
    args = ['install', "#{name}@#{version}", '--no-color']
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

    @runCommand(command, args, exit)

  uninstall: ({name}, callback) ->
    atom.packages.deactivatePackage(name) if atom.packages.isPackageActive(name)

    command = @apmCommand
    args = ['uninstall', name, '--no-color']
    exit = (code, stdout, stderr) ->
      if code is 0
        atom.packages.unloadPackage(name) if atom.packages.isPackageLoaded(name)
        callback()
      else
        error = new Error("Uninstalling '#{name}' failed.")
        error.stdout = stdout
        error.stderr = stderr
        callback(error)

    @runCommand(command, args, exit)
