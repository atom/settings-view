ownerFromRepository = (repository) ->
  return '' unless repository
  loginRegex = /github\.com\/([\w-]+)\/.+/
  if typeof(repository) is "string"
    repo = repository
  else
    repo = repository.url
    if repo.match 'git@github'
      repoName = repo.split(':')[1]
      repo = "https://github.com/#{repoName}"
  repo.match(loginRegex)?[1] ? ''

module.exports = {ownerFromRepository}
