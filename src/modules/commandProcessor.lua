local discordia = require("discordia")
local commands = require("../cmd/commands")
local utils = require("../utils")
local config = require("../config")
local permissions = require("../permissions")
local arenas = require("./arenas")
local database = require("../db/database")

local processor = {}

local function appropriate_channel(channel, command)
    if command.is_arena_room_command then
        return arenas.is_arena_room(channel)
    end

    local guild = channel.parent
    local special_channel = command.special_channel

    if special_channel ~= nil then
        return database.is_special_channel(guild, channel, special_channel)
    end

    local bot_channels_enabled = database.bot_channels_enabled(guild)

    if not bot_channels_enabled then
        return true
    end

    local bot_channels = database.get_bot_channels(guild)

    return utils.table_contains(bot_channels, channel.id)
end

local function has_rights_ro_use(user, guild, command)
    local requirement = command.requirement

    if requirement == nil then 
        return true
    end
    
    return permissions.has_permission(guild, user, requirement)
end

local function process_command(msg)
    local channel = msg.channel
    local content = msg.content
    local guild = msg.guild

    if msg.author.bot or not utils.starts_with(content, database.get_prefix(guild) or config.default_prefix) then
        return
    end

    local split = utils.split(content, " ")
    local first = split[1]
    local name = first:sub(2, #first):lower()
    content = content:sub(#first + 2) or ""
    local author = msg.author
    
    for _, command in ipairs(commands) do
        if command.name == name then
            local can_run, error_message = processor.can_run_command(channel, author, command)

            if not can_run then
                if error_message ~= nil then
                    channel:send(error_message)
                end

                return
            end

            local passed_args = {}
            local last_index = 0

            for i = 1, #split do
                local do_break
                local passed_arg
                local arg = command.args[i]
                local index = utils.find_not_white_space(content, last_index)

                if arg ~= nil and arg:should_ignore_spaces() then
                    if index ~= nil then
                        passed_arg = content:sub(index)
                    end

                    do_break = true
                else
                    if index ~= nil then
                        local end_index = content:find(" ", index)

                        if end_index == nil then
                            passed_arg = content:sub(index)
                            do_break = true
                        else
                            passed_arg = content:sub(index, end_index - 1)
                            last_index = end_index + 1
                        end
                    end
                end

                if passed_arg ~= nil then
                    table.insert(passed_args, passed_arg)
                end

                if passed_arg == nil or do_break then
                    break
                end
            end

            local query = {
                guild = guild,
                author = author,
                member = msg.member,
                channel = channel
            }

            function query.reply(content)
                return channel:send(content)
            end

            command:run(query, passed_args)

            break
        end
    end
end

function processor.init()
    discordia.storage.client:on("messageCreate", function(msg)
        if msg.guild == nil then
            return
        end

        process_command(msg)
    end)
end

function processor.can_run_command(channel, author, command)
    if not appropriate_channel(channel, command) then
        return false
    elseif not has_rights_ro_use(author, channel.guild, command) then 
        return false, "You don't have enough permissions to use this command"
    end

    return true
end

return processor