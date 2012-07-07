module.exports = (robot) ->
  http = require 'scoped-http-client'

  robot.hear /\[([^\/]+)\/(.+)\] (Passed|Failed):.*\((https:\/\/semaphoreapp\.com\/projects.*)\)/, (msg) ->
    repo = msg.match[1]
    branch = msg.match[2]
    failed = msg.match[3] == 'Failed'
    build_url = msg.match[4]

    url = "https://api.github.com" + "/repos/PrimeRevenue/#{repo}/pulls"
    github_req = http.create(url)
    github_req = github_req.header('Authorization', "token #{oauth_token}") if (oauth_token = process.env.HUBOT_GITHUB_TOKEN)?
    github_req = github_req.header('Accept', 'application/json')
    github_req = github_req.header('Content-Type', 'application/json')

    github_req.get()((error, rsp, body) ->
      pull_request = null

      pulls = JSON.parse body if body?
      
      if pulls?
        for pull in pulls
          if pull.head.ref == branch
            pull_request = pull

      status = if failed then "FAILED" else "SUCCESSFUL"
      status_emoji = if failed then ":-1:" else ":+1:"

      message = "#{status_emoji} Semaphore build: #{status}, [Build Details...](#{build_url})"

      if pull_request?
        comment = "{ \"body\": \"#{message}\" }"
        url = "https://api.github.com" + "/repos/PrimeRevenue/#{repo}/issues/#{pull_request.number}/comments"
        req = http.create(url)
        req = req.header('Authorization', "token #{oauth_token}") if (oauth_token = process.env.HUBOT_GITHUB_TOKEN)?
        req = req.header('Accept', 'application/json')
        req = req.header('Content-Type', 'application/json')

        req.post(comment)((error, rsp, body) ->
          msg.send "Pull request (#{pull_request.title}) updated with build status."
        )
    )
