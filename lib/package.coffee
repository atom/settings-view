module.exports =
class Package
  constructor: (pkg, @packageManager) ->
    @name = pkg.name
