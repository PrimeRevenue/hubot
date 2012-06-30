module.exports = (robot) ->
  github = require('githubot')(robot)

  robot.router.post "/hubot/circle", (req, res) ->
    repo_url = req.body.vcs_url.split('/')
    repo_name = repo_url.pop()
    owner_name = repo_url.pop()
    branch = req.body.branch
    failed = req.body.failed

    repo = github.qualified_repo "#{owner_name}/#{repo_name}"

    github.get "/repos/#{repo}/pulls", (pulls) =>
      pull_request = null
      
      for pull in pulls
        if pull.head.ref == branch
          pull_request = pull

      user = robot.userForId 'broadcast'
      user.room = '512532'

      status = if failed then "FAILED" else "SUCCESSFUL"
      status_emoji = if failed then ":-1:" else ":+1:"
      
      req_msg =
        if pull_request?
          "for pull request: #{pull_request.title}"
        else
          ""

      for action in req.body.action_logs
        if action.bash_command? && action.bash_command.indexOf('bundle exec rspec') != -1
          for out in action.out
            if out.message? && result = out.message.match(/([0-9]+) examples, ([0-9]+) failure/)
              rspec_tests = result[1]
              rspec_failures = result[2]
            else if out.message? && result = out.message.match(/Coverage report generated for RSpec.*LOC \(([0-9]+\.[0-9]+%)\) covered/)
              coverage = result[1]
        else if action.bash_command? && action.bash_command.indexOf('phantomjs') != -1
          for out in action.out
            if out.message? && result = out.message.match(/Total: ([0-9]+), Passed: [0-9]+, Failed: ([0-9]+)/)
              qunit_tests = result[1]
              qunit_failures = result[2]

      test_status =
        "RSpec tests: #{rspec_tests} tests run, #{rspec_failures} failed\n" +
        "Coverage: #{coverage}\n" +
        "QUnit tests: #{qunit_tests} tests run, #{qunit_failures} failed\n"

      pull_message =
        "#{status_emoji} Circle build: #{status}\n\n" +
        test_status

      if pull_request?
        comment = {body: pull_message}
        github.post "/repos/#{repo}/issues/#{pull_request.number}/comments"

      robot.send user, "[Circle] Build #{status} on #{repo_name} at #{branch} #{req_msg}", test_status

      res.writeHead 200, {'Content-Type': 'text/plain'}
      res.end 'Thanks'
