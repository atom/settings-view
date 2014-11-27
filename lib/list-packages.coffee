# This is probably only temporary until this is merged https://github.com/atom/apm/pull/216
child_process = require 'child_process'
fs = require './fs'
path = require 'path'
semver = require 'semver'
CSON = require 'season'


module.exports =
class ListPackages
  constructor: ->
    @userPackagesDirectory = path.join(atom.getConfigDirPath(), 'packages')
    @devPackagesDirectory = path.join(atom.getConfigDirPath(), 'dev', 'packages')

  listPackages: (directoryPath, options) ->
    packages = []
    for child in fs.list(directoryPath)
      continue unless fs.isDirectorySync(path.join(directoryPath, child))

      manifest = null
      if manifestPath = CSON.resolve(path.join(directoryPath, child, 'package'))
        try
          manifest = CSON.readFileSync(manifestPath)
      manifest ?= {}
      manifest.name = child
      if options?.themes
        packages.push(manifest) if manifest.theme
      else
        packages.push(manifest)

    packages

  listUserPackages: (options, callback) ->
    callback?(null, @listPackages(@userPackagesDirectory, options))

  listDevPackages: (options, callback) ->
    callback?(null, @listPackages(@devPackagesDirectory, options))

  listBundledPackages: (options, callback) ->
    @getResourcePath (resourcePath) =>
      nodeModulesDirectory = path.join(resourcePath, 'node_modules')
      packages = @listPackages(nodeModulesDirectory, options)

      try
        metadataPath = path.join(resourcePath, 'package.json')
        {packageDependencies, _atomPackages} = JSON.parse(fs.readFileSync(metadataPath))
      packageDependencies ?= {}
      _atomPackages ?= {}

      if options?.json
        packageMetadata = (v['metadata'] for k, v of _atomPackages)
        packages = packageMetadata.filter ({name}) ->
          packageDependencies.hasOwnProperty(name)
      else
        packages = packages.filter ({name}) ->
          packageDependencies.hasOwnProperty(name)

      callback?(null, packages)

  getResourcePath: (callback) ->
    if process.env.ATOM_RESOURCE_PATH
      process.nextTick -> callback(process.env.ATOM_RESOURCE_PATH)
    else
      apmFolder = path.resolve(__dirname, '..', '..', '..')
      appFolder = path.dirname(apmFolder)
      if path.basename(apmFolder) is 'apm' and path.basename(appFolder) is 'app'
        process.nextTick -> callback(appFolder)
      else
        switch process.platform
          when 'darwin'
            child_process.exec 'mdfind "kMDItemCFBundleIdentifier == \'com.github.atom\'"', (error, stdout='', stderr) ->
              appLocation = stdout.split('\n')[0] ? '/Applications/Atom.app'
              callback("#{appLocation}/Contents/Resources/app")
          when 'linux'
            process.nextTick -> callback('/usr/local/share/atom/resources/app')
          when 'win32'
            process.nextTick =>
              programFilesPath = path.join(process.env.ProgramFiles, 'Atom', 'resources', 'app')

              # Scan for latest chocolatey install version when not in program files
              unless fs.isDirectorySync(programFilesPath)
                if process.env.CHOCOLATEYINSTALL
                  chocolateyLibPath = path.join(process.env.CHOCOLATEYINSTALL, 'lib')

                if process.env.ALLUSERSPROFILE and not fs.isDirectorySync(chocolateyLibPath)
                  chocolateyLibPath = path.join(process.env.ALLUSERSPROFILE, 'chocolatey', 'lib')

                latestVersion = null
                for child in fs.list(chocolateyLibPath)
                  if child.indexOf('Atom.') is 0
                    version = child.substring(5)
                    if semver.valid(version)
                      latestVersion ?= version
                      latestVersion = version if semver.gt(version, latestVersion)

                if latestVersion
                  appLocation = path.join(chocolateyLibPath, "Atom.#{version}", 'tools', 'Atom', 'resources', 'app')
                  return callback(appLocation) if fs.isDirectorySync(appLocation)

              callback(programFilesPath)

  getPackages: (callback, options) ->
    out =
      core: []
      dev: []
      user: []

    @listBundledPackages options, (err, packages) =>
      out.core = packages
      @listDevPackages options, (err, packages) =>
        out.dev = packages
        @listUserPackages options, (err, packages) =>
          out.user = packages
          callback(null, out)
