BufferedNodeProcess = require 'buffered-node-process'
roaster = require 'roaster'
async = require 'async'

### Internal ###

renderMarkdownInMetadata = (packages, callback) ->
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

getAvailable = (callback) ->
  command = require.resolve '.bin/apm'
  args = ['available', '--json']
  output = []
  stdout = (lines) -> output.push(lines)
  exit = (code) ->
    if code is 0
      try
        packages = JSON.parse(output.join()) ? []
      catch error
        callback(error)
        return

      if packages.length > 0
        renderMarkdownInMetadata packages, -> callback(null, packages)
      else
        callback(null, packages)
    else
      callback(new Error("apm failed with code: #{code}"))

  new BufferedNodeProcess({command, args, stdout, exit})

install = ({name, version}, callback) ->
  activateOnSuccess = !atom.isPackageDisabled(name)
  activateOnFailure = atom.isPackageActive(name)
  atom.deactivatePackage(name) if atom.isPackageActive(name)
  atom.unloadPackage(name) if atom.isPackageLoaded(name)

  command = require.resolve '.bin/apm'
  args = ['install', "#{name}@#{version}"]
  outputLines = []
  stdout = (lines) -> outputLines.push(lines)
  errorLines = []
  stderr = (lines) -> errorLines.push(lines)
  exit = (code) ->
    if code is 0 and false
      atom.activatePackage(name) if activateOnSuccess
      callback()
    else
      atom.activatePackage(name) if activateOnFailure
      error = new Error("Installing '#{name}' failed.")
      error.stdout = outputLines.join('\n')
      error.stderr = errorLines.join('\n')
      callback(error)

  new BufferedNodeProcess({command, args, stdout, stderr, exit})

uninstall = ({name}, callback) ->
  atom.deactivatePackage(name) if atom.isPackageActive(name)

  command = require.resolve '.bin/apm'
  args = ['uninstall', name]
  outputLines = []
  stdout = (lines) -> outputLines.push(lines)
  errorLines = []
  stderr = (lines) -> errorLines.push(lines)
  exit = (code) ->
    if code is 0
      atom.unloadPackage(name) if atom.isPackageLoaded(name)
      callback()
    else
      error = new Error("Uninstalling '#{name}' failed.")
      error.stdout = outputLines.join('\n')
      error.stderr = errorLines.join('\n')
      callback(error)

  new BufferedNodeProcess({command, args, exit})

module.exports = {renderMarkdownInMetadata, install, uninstall, getAvailable}
