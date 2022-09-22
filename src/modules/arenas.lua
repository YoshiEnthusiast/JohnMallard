local discordia = require("discordia")
local utils = require("../utils")
local data = require("../arena/arenaData")
local database = require("../db/database")
local Arena = require("../arena/Arena")

local function get_players_table(players, key)
    local rows = {}

    for index, player in ipairs(players) do
        table.insert(rows, {
            {
                name = "#",
                value = index
            },
            {
                name = "name",
                value = utils.name_by_id(player["id"])
            },
            {
                name = key,
                value = player[key]
            }
        })
    end

    return utils.build_table(rows)
end

local function create_players_page(title, players, key)
    local page = {
        title = title
    }

    if #players > 0 then
        page.fields = get_players_table(players, key)
    else
        page.description = "No players yet!"
    end

    return page
end

local arenas = {}

function arenas.init()
    discordia.storage.client:on("reactionAdd", function(reaction, userId)
        local guild = reaction.message.guild

        if guild == nil or guild:getMember(userId).bot then
            return
        end

        local arena = data.current[guild.id]

        if arena ~= nil then
            arena:on_reaction_added(reaction)
        end
    end)
end

function arenas.try_call_func(query, func, log_error)
    local arena = data.get_current_arena(query.guild)

    if arena ~= nil then
        return func(arena)
    elseif log_error then
        query.reply("Arena hasn't been created")
    end
end

function arenas.create(query, name, players_per_team)
    local guild = query.guild

    if data.get_current_arena(guild) ~= nil then
        query.reply("You cannot create multiple arenas at once")
        return
    end

    if database.get_rank_roles(guild) == nil then
        query.reply("Ranking roles must be set")
        return
    end

    local log_channel_id = database.get_special_channel(guild, "arenainfo")

    if log_channel_id == nil then
        query.reply("Special channel " .. utils.quote("arenainfo") .. " needs to be set to start the arena")
        return
    end

    local arena = Arena({
        name = name,
        log_channel = guild:getChannel(log_channel_id),
        players_per_team = players_per_team
    })

    data.add_arena(guild, arena)

    query.reply("Arena " .. utils.quote(name) .. " has been created")
end

function arenas.is_arena_room(query)
    local result = arenas.try_call_func(query, function(arena)
        return arena:is_arena_room(query.channel)
    end)

    return result == true
end

function arenas.send_leaderboard(query)
    local guild = query.guild

    local players_by_elo = database.get_players_by_elo(guild)
    local players_by_wins = database.get_players_by_wins(guild)

    utils.send_pages_menu_buttons(query, {
        create_players_page("Elo leaderboard", players_by_elo, "elo"),
        create_players_page("Wins leaderboard", players_by_wins, "wins")
    })
end

function arenas.send_stats(query, member)
    local guild = query.guild
    local player = database.get_arena_player(guild, member)

    if player == nil then
        query.reply("You need to play at least one arena match to be able to view you stats")
        return
    end

    local fields = utils.make_inline({
        {
            name = "Name",
            value = utils.get_full_name(guild:getMember(player["id"]).user)
        },
        {
            name = "Elo",
            value = player["elo"]
        },
        {
            name = "Wins",
            value = player["wins"]
        },
        {
            name = "Losses",
            value = player["losses"]
        },
        {
            name = "Arena wins",
            value = player["arena_wins"]
        }
    })

    utils.send_embed(query, {
        fields = fields,
        image_url = member:getAvatarURL(1024)
    })
end

return arenas


