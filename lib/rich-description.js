const marked = require('marked')

const renderer = new marked.Renderer()
renderer.code = () => ''
renderer.blockquote = () => ''
renderer.heading = () => ''
renderer.br = () => '<br/>'
renderer.html = () => ''
renderer.image = () => ''
renderer.list = () => ''

const markdown = text => marked(text, {renderer, breaks: true}).replace(/<p>(.*)<\/p>/, '$1').trim()

module.exports = {
  getSettingDescription (keyPath) {
    const schema = atom.config.getSchema(keyPath)
    let description = ''
    if (schema && schema.description) {
      description = schema.description
    }
    return markdown(description)
  }
}
