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

  unless repo.match("github.com/")
    repo = "https://github.com/#{repo}"

  repo.match(loginRegex)?[1] ? ''

packageComparatorAscending = (left, right) ->
  leftStatus = atom.packages.isPackageDisabled(left.name)
  rightStatus = atom.packages.isPackageDisabled(right.name)
  if leftStatus is rightStatus
    if left.name > right.name
      -1
    else if left.name < right.name
      1
    else
      0
  else if leftStatus > rightStatus
    -1
  else
    1

module.exports = {ownerFromRepository, packageComparatorAscending}
