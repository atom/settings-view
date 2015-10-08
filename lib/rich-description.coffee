marked = require 'marked'

renderer = new marked.Renderer()
renderer.code = -> ''
renderer.blockquote = -> ''
renderer.heading = -> ''
renderer.html = -> ''
renderer.image = -> ''
renderer.list = -> ''

markdown = (text) ->
  marked(text, renderer: renderer).replace(/<p>(.*)<\/p>/, "$1").trim()

module.exports =
  getSettingDescription: (keyPath) ->
    description = atom.config.getSchema(keyPath)?.description or ''
    markdown(description)
