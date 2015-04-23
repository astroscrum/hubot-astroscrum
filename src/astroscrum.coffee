# Description:
#   Interface with Astroscrum API
#
# Configuration:
#   HUBOT_URL
#   HUBOT_ASTROSCRUM_AUTH_TOKEN
#
# Options:
#   HUBOT_ASTROSCRUM_SUBDOMAIN
#   HUBOT_ASTROSCRUM_URL
#
# Commands:
#   hubot join - join your team's daily scrum
#   hubot players - return all the players on your team
#   hubot scrum summary - returns the current summary for today
#   hubot today - what you're doing today, you can have many entries
#   hubot yesterday - what you did yesterday
#   hubot blocked - what you are blocked by
#

request = require('request')

host = process.env.HUBOT_URL
token = process.env.HUBOT_ASTROSCRUM_AUTH_TOKEN
url = process.env.HUBOT_ASTROSCRUM_URL || "https://astroscrum-api.herokuapp.com/v1"

# Default time to tell users to do their scrum
PROMPT_AT = process.env.HUBOT_SCRUM_PROMPT_AT || '0 0 6 * * *' # 6am everyday

# Default scrum reminder time
REMIND_AT = process.env.HUBOT_SCRUM_REMIND_AT || '0 30 11 * * *' # 11am everyday

# Send the scrum at 10 am everyday
SUMMARY_AT = process.env.HUBOT_SCRUM_SUMMARY_AT || '0 0 12 * * *' # noon

# Set to local timezone
TIMEZONE = process.env.TZ || "America/Los_Angeles"

# Setup cron
CronJob = require("cron").CronJob

# Handlebars
Handlebars = require('handlebars')

get = (path, handler) ->
  # token = robot.brain.data.get "astroscrum-auth-token"
  options = { url: url + path, headers: "X-Auth-Token": token }
  request.get options, (err, res, body) ->
    handler JSON.parse(body)

post = (path, data, handler) ->
  # token = robot.brain.data.get "astroscrum-auth-token"
  options = { url: url + path, json: data, headers: "X-Auth-Token": token }
  request.post options, (err, res, body) ->
    handler JSON.stringify(body)

setup = (robot, handler) ->
  data =
    team:
      slack_id: robot.adapter.client.team.id
      name: robot.adapter.client.team.name
      bot_url: host
      timezone: TIMEZONE
      prompt_at: PROMPT_AT
      remind_at: REMIND_AT
      summary_at: SUMMARY_AT

  post '/team', data, (response) ->
    handler JSON.parse(response)

messages =
  prompt: (robot) ->
    get '/players', (response) ->
      for player in response.players
        get '/players/' + player.slack_id, (response) ->
          robot.send { room: response.player.name }, templates.prompt(response)

  reminder: (robot) ->
    get '/players', (response) ->
      for player in response.players
        get '/players/' + player.slack_id, (response) ->
          robot.send { room: response.player.name }, templates.reminder(response)

  summary: (robot) ->
    get '/players', (playersResponse) ->
      get '/scrum', (scrumResponse) ->
        for player in playersResponse.players
          robot.send { room: player.name }, templates.summary(scrumResponse)

# Templates
templates =
  players: (players) ->
    source = """
      {{#each players}}
      *{{real_name}}* ({{points}})
      {{/each}}
    """
    template = Handlebars.compile(source)
    template(players)

  prompt: (player) ->
    source = """
      Hey {{player.name}}, are you ready to do your scrum?! Message me back with `scrum help` if you need any details on how to do your scrum.
    """
    template = Handlebars.compile(source)
    template(player)

  reminder: (player) ->
    source = """
      Hey {{player.name}}, you didn't finish your scrum today!
    """
    template = Handlebars.compile(source)
    template(player)

  summary: (scrum) ->
    source = """
      Team summary for {{scrum.date}}:
      {{#each scrum.players}}
      *{{real_name}}*
      {{#each categories}}
          {{category}}:
          {{#each entries}}
           - {{body}}
          {{/each}}
      {{/each}}

      {{/each}}
    """
    template = Handlebars.compile(source)
    template(scrum)

  join: (player) ->
    console.log(player)
    source = """
      {{player.name}}, you've joined Astroscrum
    """
    template = Handlebars.compile(source)
    template(player)

  entry: (entry) ->
    console.log(entry)
    source = """
      Got it! {{entry.category}}, {{entry.body}}
    """
    template = Handlebars.compile(source)
    template(entry)

  help: (player) ->
    console.log(player)
    source = """
      Hey {{player.name}}, you can say "today I need to organize my desk", "yesterday I cleaned up some code", or "blocked @mogramer owes me something".

      You can enter something for each of these:
       • *today*
       • *yesterday*
       • *blocked* (optional)
    """
    template = Handlebars.compile(source)
    template(player)

module.exports = (robot) ->

  loaded = false
  robot.brain.on 'loaded', (data) ->
    setup robot, (response) ->
      console.log(response)

      if loaded == false
        robot.brain.set "astroscrum-auth-token", response.team.auth_token
        loaded = true

      console.log('Astroscrum team saved!')

  robot.respond /scrum players/i, (msg) ->
    get '/players', (response) ->
      robot.send { room: msg.envelope.user.name }, templates.players(response)

  robot.respond /scrum prompt/i, (msg) ->
    get '/players/' + msg.envelope.user.id, (response) ->
      robot.send { room: msg.envelope.user.name }, templates.prompt(response)

  robot.respond /scrum reminder/i, (msg) ->
    get '/players/' + msg.envelope.user.id, (response) ->
      robot.send { room: msg.envelope.user.name }, templates.reminder(response)

  robot.respond /scrum summary/i, (msg) ->
    get '/scrum', (response) ->
      robot.send { room: msg.envelope.user.name }, templates.summary(response)

  robot.respond /scrum join/i, (msg) ->
    player = robot.brain.userForId(msg.envelope.user.id)
    data =
      player:
        slack_id: player.id
        name: player.name
        real_name: player.real_name
        email: player.email_address
        password: player.id

    post '/players', data, (response) ->
      response = JSON.parse(response)
      robot.send { room: msg.envelope.user.name }, templates.join(response)

  robot.respond /(today|yesterday|blocked) (.*)/i, (msg) ->
    player = robot.brain.userForId(msg.envelope.user.id)
    data =
      entry:
        slack_id: player.id
        category: msg.match[1]
        body: msg.match[2]

    post '/entries', data, (response) ->
      response = JSON.parse(response)
      robot.send { room: msg.envelope.user.name }, templates.entry(response)

  robot.respond /scrum help/i, (msg) ->
    get '/players/' + msg.envelope.user.id, (response) ->
      robot.send { room: msg.envelope.user.name }, templates.help(response)

  ##
  # TODO:
  # Direct message entire team
  robot.router.post "/hubot/astroscrum/team", (req, res) ->
    console.log(req.body)
    # robot.emit "prompt", req.body

  ##
  # TODO:
  # Direct message specific user
  robot.router.post "/hubot/astroscrum/player/:slack_id", (req, res) ->
    player = robot.brain.userForId(req.params.slack_id)
    console.log(player)
    console.log(req.body)
    # robot.emit "prompt", req.body

  ##
  # FIXME: handle scheduling api-side
  # Setup things that need scheduling
  schedule =
    prompt: (time) ->
      new CronJob(time, ->
        messages.prompt(robot)
        return
      , null, true, TIMEZONE)

    remind: (time) ->
      new CronJob(time, ->
        messages.reminder(robot)
        return
      , null, true, TIMEZONE)

    summary: (time) ->
      new CronJob(time, ->
        messages.summary(robot)
        return
      , null, true, TIMEZONE)


  # Schedule prompt to tell user to do their scrum today
  schedule.prompt PROMPT_AT

  # Schedule reminder to remind the user they still need to do their scrum
  schedule.remind REMIND_AT

  # Schedule the end time of the scrum, deliver the summary to the players
  schedule.summary SUMMARY_AT

