# Hubot Astroscrum API adapter

[![Join the Astroscrum chat](https://astroscrum-slackin.herokuapp.com/badge.svg)](https://astroscrum-slackin.herokuapp.com/)

This Hubot script allows hubot to interface directly to the Astroscrum API

## Commands

    hubot scrum help

## Customize

You can adjust the schedule that the bot will nag you to do your scrum, the following are the defaults, but you can send in any crontab-like patter such as: `'0 0 10 * * *'` for 10 am.

Default time to tell users to do their scrum:

    HUBOT_SCRUM_PROMPT_AT='0 0 6 * * *' # 6am everyday

Default scrum reminder time:

    HUBOT_SCRUM_REMIND_AT='0 30 11 * * *' # 11am everyday

Send the scrum at 10 am everyday:

    HUBOT_SCRUM_SUMMARY_AT='0 0 12 * * *' # noon


## Development

The best way is to use `npm link`:

```
hubot-scrum$ npm link
hubot-scrum$ cd /path/to/your/hubot
hubot$ npm link hubot-astroscrum
hubot$ bin/hubot
