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

HOST_URL = process.env.HUBOT_URL || "https://astroscrum-slackbot.herokuapp.com"
token = process.env.HUBOT_ASTROSCRUM_AUTH_TOKEN
url = process.env.HUBOT_ASTROSCRUM_URL || "https://astroscrum-api.herokuapp.com/v1"

# Default time to tell users to do their scrum
PROMPT_AT = process.env.HUBOT_SCRUM_PROMPT_AT || "0 6 * * * *" # 6am everyday

# Default scrum reminder time
REMIND_AT = process.env.HUBOT_SCRUM_REMIND_AT || "30 11 * * * *" # 11:30am everyday

# Send the scrum at 10 am everyday
SUMMARY_AT = process.env.HUBOT_SCRUM_SUMMARY_AT || "0 12 * * * *" # noon

# Set to local timezone
TIMEZONE = process.env.TZ || "America/Los_Angeles"

# Handlebars
Handlebars = require('handlebars')

get = (path, handler) ->
  # console.log robot.brain.get "astroscrum-auth-token"
  options = { url: url + path, headers: "X-Auth-Token": token }
  request.get options, (err, res, body) ->
    handler JSON.parse(body)

post = (path, data, handler) ->
  # console.log robot.brain.get "astroscrum-auth-token"
  options = { url: url + path, json: data, headers: "X-Auth-Token": token }
  request.post options, (err, res, body) ->
    handler JSON.stringify(body)

setup = (robot, handler) ->
  data =
    team:
      slack_id: robot.adapter.client.team.id
      name: robot.adapter.client.team.name
      bot_url: HOST_URL
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

  ##
  # TODO: get and set astroscrum-auth-token automatically
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

  # Direct message entire team
  robot.router.post "/hubot/astroscrum/announce", (req, res) ->
    console.log(req.body)
    template = Handlebars.compile(req.body.template)
    robot.send { room: req.body.channel }, template(req.body.data)
    res.send 'OK'

  # Direct message specific user
  robot.router.post "/hubot/astroscrum/message", (req, res) ->
    console.log(req.body)
    template = Handlebars.compile(req.body.template)
    for slack_id in req.body.players
      player = robot.brain.userForId(slack_id)
      robot.send { room: player.name }, template(req.body.data)
    res.send 'OK'

