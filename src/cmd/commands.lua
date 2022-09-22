local args = require("./args")
local config = require("../config")
local utils = require("../utils")
local arenas = require("../modules/arenas")
local permissions = require("../permissions")
local Command = require("./Command")
local database = require("../db/database")
local elo = require("../arena/elo")

require("discordia-components")

local sections = {}

local commands = {}

local function valid_command(command)
    local optional = false
    local args = command.args
    local length = #args

    for index, arg in ipairs(args) do
        if arg.optional then
            optional = true
        elseif optional then
            return false
        end

        if arg:should_ignore_spaces() and index ~= length then 
            return false
        end
    end

    return true
end

local function add_command(props)
    local command = Command(props)

    if valid_command(command) then
        local section = command.section

        if not utils.table_contains(sections, section) then
            table.insert(sections, section)
        end

        table.insert(commands, command)
    end
end

local function get_heighest_role_position(member)
    local role = member.heighestRole

    if role == nil then
        return 0
    end

    return role.position
end

local function punish_member(query, member, permission, action, callback, success_msg)
    local guild = query.guild
    local me = guild.me
    local id = member.id

    if me.id == id then
        query.reply("You cannot " .. action .. " the bot")
        return
    elseif query.author.id == id then
        query.reply("You cannot " .. action .. " yourself")
        return
    elseif not me:hasPermission(permission) then
        query.reply("Missing the permission to " .. action .. " members")
        return
    end

    local heighestPosition = get_heighest_role_position(member)
    local name = member.name

    if get_heighest_role_position(me) < heighestPosition or guild.ownerId == member.id then
        query.reply("I don't have enough rights to " .. action .. " " .. name)
        return
    end

    if get_heighest_role_position(query.author) < heighestPosition then
        query.reply("Unable to " .. action .. " " .. name .. " because they have heigher roles than you")
        return
    end

    callback()
    query.reply(success_msg)
end

local function get_section_commands_embed(section)
    local fields = {}

    for _, command in ipairs(commands) do
        if command.section == section then
            local command_info = command.description .. "."
            local requirement = command.requirement

            if requirement ~= nil then
                command_info = command_info .. " " .. "Requirement: " .. requirement .. "."
            end

            local field = {
                name = command:get_demo_string(),
                value = command_info
            }
            
            table.insert(fields, field)
        end
    end
    
    return {
        title = utils.first_to_upper(section) .. " commands",
        fields = fields
    }
end

add_command({
    name = "suggestionschannel",
    args = {
        args.Channel({
            name = "channel",
            optional = true
        })
    },
    execute = function(query, args)
        local suggestions_channel = args["channel"]
        local guild = query.guild

        if suggestions_channel == nil then
            database.remove_suggestions_channel(guild)
            query.reply("Suggestions channel removed")
        else
            database.set_suggestions_channel(guild, suggestions_channel)
            query.reply("Suggestions channel was set to " .. suggestions_channel.mentionString)
        end
    end,
    requirement = "admin",
    description = "Sets\\removes suggestions channel",
    section = "moderation"
})

add_command({
    name = "avatar",
    args = {
        args.Member({
            name = "member",
            optional = "true"
        })
    },
    execute = function(query, args)
        local member = args["member"] or query.author

        utils.send_embed(query, {
            title = member.name .. "'s avatar",
            image_url = member:getAvatarURL(1024)
        })
    end,
    description = "Sends user's avatar",
    section = "misc"
})

add_command({
    name = "permission",
    args = {
        args.String({ 
            name = "permission" 
        }),
        args.Role({
            name = "role",
            optional = true
        })
    },
    execute = function(query, args)
        local permission = args["permission"]

        if not utils.table_contains(permissions.all, permission) then
            query.reply("Permission " .. permission .. " does not exist")
            return
        end

        local guild = query.guild
        local role = args["role"]

        if role ~= nil then 
            database.set_permission(guild, permission, role.id)
            query.reply("Permission " .. permission.." is given to role " .. role.name)
        else
            database.clear_permission(guild, permission)
            query.reply("Cleared permission " .. permission)
        end
    end,
    requirement = "owner",
    description = "Sets permission to a role. If role argument is missing, permission is removed from the role",
    section = "moderation"
})

add_command({
    name = "botchannels",
    args = {
        args.Bool({ 
            name = "enabled" 
        })
    },
    execute = function(query, args)
        local enabled = args["enabled"]
        database.set_bot_channels_enabled(query.guild, enabled)
        local sign 

        if enabled then
            sign = "enabled"
        else
            sign = "disabled"
        end

        query.reply("Bot channels "..sign)
    end,
    requirement = "admin",
    description = "Enables\\disables bot channels",
    section = "moderation"
})

add_command({
    name = "togglebotchannel",
    args = {
        args.Channel({ 
            name = "channel" 
        })
    },
    execute = function(query, args)
        local channel = args["channel"]
        local guild = query.guild
        local bot_channels = database.get_bot_channels(guild)

        local sign

        if utils.table_contains(bot_channels, channel.id) then
            database.remove_bot_channel(guild, channel)
            sign = "is removed from bot channels"
        else
            database.add_bot_channel(guild, channel)
            sign = "is added to bot channels"
        end

        query.reply("Channel " .. channel.mentionString .. " " .. sign)
    end,
    requirement = "admin",
    description = "Toggles bot channel",
    section = "moderation"
})

add_command({
    name = "duck",
    execute = function(query)
        local image_url, error = utils.search_image("duck")

        if error ~= nil then
            query.reply(error)
            return
        end

        utils.send_embed(query, {
            title = "Duck",
            image_url = image_url,
            color = "#a83905"
        })
    end,
    description = "Sends a picture of a duck :)",
    section = "misc"
})

add_command({
    name = "ban",
    args = {
        args.Member({ 
            name = "member" 
        }),
        args.Number({
            name = "days",
            optional = true
        }),
        args.String({
            name = "reason",
            optional = true,
            ignore_spaces = true
        })
    },
    execute = function(query, args)  
        local member = args["member"]

        punish_member(query, member, "banMembers", "ban", function()
            local days
            local raw_days = args["days"] or 0

            if raw_days > 0 then
                days = math.min(raw_days, 7)
            end

            query.guild:banUser(member.id, args["reason"], days)
        end, "Member " .. member.name .. " banned")
    end,
    requirement = "mod",
    description = "Bans member. If " .. utils.quote("days") .. " argument is less than or equal to zero, the member gets banned permanently. Max number of days is 7",
    section = "moderation",
    prefix_only = true
})

add_command({
    name = "kick",
    args = {
        args.Member({ 
            name = "member" 
        }),
        args.String({
            name = "reason",
            optional = true,
            ignore_spaces = true
        })
    },
    execute = function(query, args)
        local member = args["member"]

        punish_member(query, member, "kickMembers", "kick", function()
            query.guild:kickUser(member.id, args["reason"])
        end, "Member " .. member.name .. " kicked")
    end,
    requirement = "mod",
    description = "Kicks member",
    section = "moderation",
    prefix_only = true
})

add_command({
    name = "help",
    args = {
        args.String({
            name = "section",
            optional = true,
            ignore_spaces = true
        })
    },
    execute = function(query, args)
        local section = args["section"]

        if section == nil then
            local reply = utils.send_embed(query, {
                title = "Help",
                description = "Select a command section. You can also add a section name to this command"
            })

            local pages = {}

            for _, section in ipairs(sections) do
                local page = {
                    name = utils.capital_letter(section),
                    content = get_section_commands_embed(section)
                }

                table.insert(pages, page)
            end

            utils.add_pages_menu(reply, pages)
        else
            utils.send_embed(query, get_section_commands_embed(section))
        end
    end,
    description = "Displays the list of commands",
    section = "misc"
})

add_command({
    name = "serverstats",
    execute = function(query)
        local guild = query.guild
        local fields = {
            {
                name = "Name",
                value = guild.name
            },
            {
                name = "Owner",
                value = utils.get_full_name(guild.owner)
            },
            {
                name = "Member count",
                value = guild.totalMemberCount
            }
        }

        utils.send_embed(query, {
            title = "Server stats",
            fields = fields,
            thumbnail = {
                url = guild.iconURL
            },
            color = "#4287f5"
        })
    end,
    description = "Prints out server stats",
    section = "misc"
})

add_command({
    name = "specialchannel",
    args = {
        args.String({
            name = "name"
        }),
        args.Channel({
            name = "channel",
            optional = true
        })
    },
    execute = function(query, args)
        local name = args["name"]
        local name_quoted = utils.quote(name)

        if not utils.table_contains(config.special_channels, name) then
            query.reply("Special channel " .. name_quoted .. " does not exist")
            return
        end

        local guild = query.guild
        local special_channel = args["channel"]

        if special_channel == nil then
            database.clear_special_channel(guild, name)
            query.reply("Special channel " .. name_quoted .. " is cleared")
        else
            database.set_special_channel(guild, special_channel, name)
            query.reply("Special channel " .. name_quoted .. " is set to "..special_channel.mentionString)
        end
    end,
    description = "Sets special channel. If " .. utils.quote("channel") .. " argument is missing, special channel is cleared",
    requirement = "admin",
    section = "moderation"
})

add_command({
    name = "scores",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:send_scores(query)
        end, true)
    end,
    special_channel = "arenachat",
    description = "Shows current arena scores",
    section = "arena"
})

add_command({
    name = "setscore",
    args = {
        args.Member({
            name = "member"
        }),
        args.Number({
            name = "score"
        })
    },
    execute = function(query, args)
        arenas.try_call_func(query, function(arena)
            arena:set_team_score(query, args["member"], args["score"])
        end, true)
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Sets player'a arena score to a specified number",
    section = "arena"
})

add_command({
    name = "join",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:add_player(query)
        end, true)
    end,
    special_channel = "arenachat",
    description = "Adds the player to the arena players list",
    section = "arena"
})

add_command({
    name = "leave",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:remove_player(query)
        end, true)
    end,
    special_channel = "arenachat",
    description = "Removes the player from the arena",
    section = "arena"
})

add_command({
    name = "forfeit",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:register_forfeit(query)
        end)
    end,
    is_arena_room_command = true,
    description = "Suggests your opponent to skip the match",
    section = "arena"
})

add_command({
    name = "whohosts",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:determine_host(query)
        end)
    end,
    is_arena_room_command = true,
    description = "Determines who hosts the game",
    section = "arena"
})

add_command({
    name = "start",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:start(query)
        end, true)
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Starts the arena",
    section = "arena"
})

add_command({
    name = "stop",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:stop(query)
        end, true)
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Stops the arena",
    section = "arena"
})

add_command({
    name = "arenaban",
    args = {
        args.Member({
            name = "member"
        })
    },
    execute = function(query, args)
        local member = args["member"]

        if member.bot then
            query.reply("You cannot arena ban a bot")
            return
        end

        local guild = member.guild
        local id = member.id

        if query.member.id == id then
            query.reply("You cannot arena ban yourself")
            return
        end

        if database.is_arena_banned(guild, member) then
            query.reply("This member is already arena banned")
            return
        end

        database.add_arena_ban(guild, member)
        query.reply("Member " .. utils.get_full_name(member) .. " arena banned")

        arenas.try_call_func(query, function(arena)
            arena:on_member_banned(member)
        end)
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Bans the player from joining arenas and kicks him out of the current one if it exists",
    section = "arena"
})

add_command({
    name = "arenaunban",
    args = {
        args.Member({
            name = "member"
        })
    },
    execute = function(query, args)
        local member = args["member"]
        local guild = member.guild

        if not database.is_arena_banned(guild, member) then
            query.reply("This member is not arena banned")
            return
        end

        database.remove_arena_ban(guild, member)
        query.reply("Member " .. utils.get_full_name(member) .. " arena unbanned")

        arenas.try_call_func(query, function(arena)
            arena:on_member_unbanned(member)
        end)
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Unbans the player in arenas if he was banned previously",
    section = "arena"
})

add_command({
    name = "create",
    args = {
        args.Number({
            name = "players_per_team"
        }),
        args.String({
            name = "name",
            ignore_spaces = true
        })
    },
    execute = function(query, args)
        arenas.create(query, args["name"], args["players_per_team"])
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Creates a new arena",
    section = "arena"
})

add_command({
    name = "rankroles",
    args = {
        args.Role({
            name = "role_one"
        }),
        args.Role({
            name = "role_two"
        }),
        args.Role({
            name = "role_three"
        }),
        args.Role({
            name = "role_four"
        }),
        args.Role({
            name = "role_five"
        }),
    },
    execute = function(query, args)
        local roles = {
            args["role_one"],
            args["role_two"],
            args["role_three"],
            args["role_four"],
            args["role_five"],
        }

        local roles_distincted = utils.distinct(roles)

        if #roles ~= #roles_distincted then
            query.reply("All roles must be different")
            return
        end

        database.set_rank_roles(query.guild, roles)
        query.reply("Ranking roles set")
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Sets roles that represent players' ranks in ascending order",
    section = "arena"
})

add_command({
    name = "clearrankroles",
    execute = function(query)
        database.clear_rank_roles(query.guild)
        query.reply("Rank roles cleared")
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Clears roles that represent players' ranks",
    section = "arena"
})

add_command({
    name = "elo",
    args = {
        args.Number({
            name = "k_factor"
        }),
        args.Number({
            name = "scale"
        })
    },
    execute = function(query, args)
        local k_factor = args["k_factor"]
        local scale = args["scale"]

        database.set_elo_config(query.guild, k_factor, scale)
        query.reply("K-factor and scale set to " .. k_factor .. " and " .. scale .. " respectively")
    end,
    special_channel = "arenachat",
    requirement = "to",
    description = "Sets k-factor and scale for elo ranking system. The defaults are " .. elo.default_k_factor .. " and " .. elo.default_scale .. " respectively",
    section = "arena"
})

add_command({
    name = "team",
    args = {
        args.Member({
            name = "member"
        })
    },
    execute = function(query, args)
        arenas.try_call_func(query, function(arena)
            arena:send_team_request(query, args["member"])
        end, true)
    end,
    special_channel = "arenachat",
    description = "Sends user a team request",
    section = "arena"
})

add_command({
    name = "accept",
    args = {
        args.Member({
            name = "member"
        })
    },
    execute = function(query, args)
        arenas.try_call_func(query, function(arena)
            arena:accept_team_request(query, args["member"])
        end, true)
    end,
    special_channel = "arenachat",
    description = "Accepts team request from a user",
    section = "arena"
})

add_command({
    name = "leaveteam",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:leave_team(query)
        end, true)
    end,
    special_channel = "arenachat",
    description = "Removes user from a team. The team will be disbanded",
    section = "arena"
})

add_command({
    name = "requests",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:display_requests(query)
        end, true)
    end,
    special_channel = "arenachat",
    description = "Displays user's sent and recieved requests",
    section = "arena"
})

add_command({
    name = "clearrequests",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:clear_requests(query)
        end, true)
    end,
    special_channel = "arenachat",
    description = "Clears user's sent requests",
    section = "arena"
})

add_command({
    name = "arenainfo",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:send_info(query)
        end, true)
    end,
    special_channel = "arenachat",
    description = "Sends information about current arena",
    section = "arena"
})

add_command({
    name = "leaderboard",
    execute = function(query)
        arenas.send_leaderboard(query)
    end,
    special_channel = "arenachat",
    description = "Sends arena leaderboard based on players elo and wins",
    section = "arena"
})

add_command({
    name = "myteam",
    execute = function(query)
        arenas.try_call_func(query, function(arena)
            arena:display_current_team(query)
        end, true)
    end,
    special_channel = "arenachat",
    description = "Shows members of your current team",
    section = "arena"
})

add_command({
    name = "stats",
    args = {
        args.Member({
            name = "member",
            optional = true
        })
    },
    execute = function(query, args)
        arenas.send_stats(query, args["member"] or query.member)
    end,
    special_channel = "arenachat",
    description = "Shows member's stats",
    section = "arena"
})

return commands

