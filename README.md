# John Mallard

Discord arena bot

What is arena?
-------

- Arena is a way of holding tournaments for different online games

How it works:

- You can join and leave at any time
- You get automatically matched into other participants based on your rating
- When you get an opponent, a separate private Discord channel is created where you can report the winner by reacting to a message
- By winning, you increase your global rank and gain points which are dispayed in arena scoreboard. Starting from the winstreak of 3, you get 2 points for winning instead of 1. When the arena is finished, a winner is determined based on the number of points

Use the `help` command to get the list of all commands

John Mallard also featutes:

- Configurable Elo ranking system
- Possibility to play in teams
- A lot of helpful commands to make you arena experience better, for example: 
  - `whohosts` — determines the lobby host if your game has a conception of lobbies
  - `forfeit` — skips the current match(needs to be used by all players in a channel)
- Elo and total wins leaderboard
- Ranking roles
- Both slash and prefix commands support
- Multiple server support
- Moderation tools such as permission system and special channels assignment
- A few misc commands

Dependencies:
-------

- [Luvit](https://github.com/luvit/luvit) — asyncronous environment for Lua
- Lit packages:
  - [Discordia](https://github.com/SinisterRectus/Discordia) — Discord API library. Discrodia extensions:
    - [discordia-components](https://github.com/Bilal2453/discordia-components)
    - [discordia-interactions](https://github.com/Bilal2453/discordia-interactions)
    - [discordia-slash](https://github.com/GitSparTV/discordia-slash)
  - [lit-sqlite3](https://github.com/SinisterRectus/lit-sqlite3)

Self Hosting
-------
- Install Luvit
- Install all the `lit` packages. All of them can be installed using `lit install [package-name]` command, except for `discordia-slash`. It should copied directly from the GitHub page to the `deps` folder because the `lit` package is deprecated
- Download [sqlite3 precompiled binary](https://sqlite.org/download.html) and put it into the root folder
- Enter yout bot token as well as google search url, engine id and api key(these are not necessary) in `config.json` file
- Run the bot using `luvit src/init.lua` command
