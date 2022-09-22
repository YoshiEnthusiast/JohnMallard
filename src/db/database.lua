local sqlite3 = require("sqlite3")
local config = require("../config")
local files = require("../files")
local builder = require("./statementBuilder")

local database_file_name = config.get_value("databasefilename")

local connection = sqlite3.open(database_file_name)
local setup_file_name = config.get_value("databasesetupfilename")

assert(files.exists(setup_file_name), "Database setup file(" .. setup_file_name .. ") not found")

local setup = files.read(setup_file_name)

assert(setup, "Database setup file read error")

connection:exec(setup)

local bool_to_number = {
    [true] = 1,
    [false] = 0
}

local function number_to_bool(data)
    for bool, number in pairs(bool_to_number) do
        if data == number then
            return bool
        end
    end
end

local function execute_statement(statement, ...)
    return statement:reset():bind(...):resultset() or {}
end

local function fetch_dicts(statement, ...)
    local data = execute_statement(statement, ...)

    if data == nil then
        return
    end

    local objects = {}

    for key, values in pairs(data) do
        for index, value in ipairs(values) do
            if objects[index] == nil then
                objects[index] = {}
            end

            objects[index][key] = value
        end
    end

    return objects
end

local function fetch_dicts_one(statement, ...)
    local dicts = fetch_dicts(statement, ...)

    if dicts == nil then
        return
    end

    return dicts[1]
end

local function value_exists(statement, ...)
    return number_to_bool(execute_statement(statement, ...)[1][1])
end

local function fetch_by_key(statement, key, ...)
    return execute_statement(statement, ...)[key] or {}
end

local function fetch_by_key_one(statement, key, ...)
    return fetch_by_key(statement, key, ...)[1]
end

local function prepare(satement)
    return connection:prepare(satement.value)
end

local order = builder.order

local statements = {
    is_special_channel = prepare(builder.exists(builder.select("1", "special_channels"):where({
        "guild_id",
        "id",
        "channel_name"
    }))),
    bot_channels_enabled = prepare(builder.select("is_enabled", "bot_channels_enabled"):where({
        "guild_id"
    }):limit(1)),
    set_bot_channels_enabled = prepare(builder.insert("bot_channels", {
        "?001",
        "?002"
    }):on_conflict("guild_id"):update({
        {
            name = "is_enabled",
            value = "?002"
        }
    })),
    bot_channels = prepare(builder.select("id", "bot_channels"):where({
        "guild_id"
    })),
    add_bot_channel = prepare(builder.insert("bot_channels", builder.get_question_marks(2))),
    remove_bot_channel = prepare(builder.delete("bot_channels"):where({
        "guild_id",
        "id"
    })),
    prefix = prepare(builder.select("prefix", "prefixes"):where({
        "guild_id"
    }):limit(1)),
    suggestions_channel = prepare(builder.select("id", "suggestions_channels"):where({
        "guild_id"
    }):limit(1)),
    set_suggestions_channel = prepare(builder.insert("suggestions_channels", {
        "?001",
        "?002"
    }):on_conflict("guild_id"):update({
        {
            name = "id",
            value = "?002"
        }
    })),
    delete_suggestions_channel = prepare(builder.delete("suggestions_channels"):where({
        "guild_id"
    })),
    set_permission = prepare(builder.insert("role_permissions", builder.get_question_marks(3))),
    clear_permission = prepare(builder.delete("role_permissions"):where({
        "guild_id",
        "permission_name"
    })),
    set_special_channel = prepare(builder.insert("special_channel", builder.get_question_marks(3))),
    clear_special_channel = prepare(builder.delete("special_channels"):where({
        "guild_id",
        "channel_name"
    })),
    arena_bans = prepare(builder.select("id", "arena_bans"):where({
        "guild_id"
    })),
    add_arena_ban = prepare(builder.insert("arena_bans", builder.get_question_marks(2))),
    remove_arena_ban = prepare(builder.delete("arena_bans"):where({
        "guild_id",
        "id"
    })),
    arena_banned = prepare(builder.exists(builder.select("1", "arena_bans"):where({
        "guild_id",
        "id"
    }))),
    set_rank_role = prepare(builder.insert("rank_roles", builder.get_question_marks(3))),
    clear_rank_roles = prepare(builder.delete("rank_roles"):where({
        "guild_id"
    })),
    get_rank_roles = prepare(builder.select("id", "rank_roles"):where({
        "guild_id"
    }):order_by("position")),
    arena_player = prepare(builder.select("*", "players"):where({
        "guild_id",
        "id"
    }):limit(1)),
    arena_players_by_wins = prepare(builder.select({
        "id",
        "arena_wins"
    }, "players"):where({
        "guild_id"
    }):order_by("arena_wins", order.descending):limit(10)),
    arena_players_by_elo = prepare(builder.select({
        "id",
        "elo"
    }, "players"):where({
        "guild_id"
    }):order_by("elo", order.descending):limit(10)),
    update_arena_player_rating = prepare(builder.update("players", {
        "elo",
        "wins",
        "losses"
    }):where({
        "guild_id",
        "id"
    })),
    update_arena_player_wins = prepare(builder.update("players", "arena_wins"):where({
        "guild_id",
        "id"
    })),
    arena_player_exists = prepare(builder.exists(builder.select("1", "players"):where({
        "guild_id",
        "id"
    }))),
    get_elo_config = prepare(builder.select({
        "k_factor",
        "scale"
    }, "elo"):where({
        "guild_id"
    })),
    set_elo_config = prepare(builder.insert("elo", {
        "?001",
        "?002",
        "?003"
    }):on_conflict("guild_id"):update({
        {
            name = "k_factor",
            value = "?002"
        },
        {
            name = "scale",
            value = "?003"
        }
    })),
    get_special_channel = prepare(builder.select("id", "special_channels"):where({
        "guild_id",
        "channel_name"
    }):limit(1).value),
    get_permissions = prepare(builder.select({
        "id",
        "permission_name"
    }, "role_permissions"):where({
        "guild_id"
    })),
    create_arena_player = prepare(builder.insert("players", {
        builder.question_mark,
        builder.question_mark,
        builder.question_mark,
        "0",
        "0",
        "0"
    }))
}

local database = {}

function database.is_special_channel(guild, channel, name)
    return value_exists(statements.is_special_channel, guild.id, channel.id, name)
end

function database.bot_channels_enabled(guild)
    return number_to_bool(fetch_by_key_one(statements.bot_channels_enabled, "is_enabled", guild.id))
end

function database.get_bot_channels(guild)
    return fetch_by_key(statements.bot_channels, "id", guild.id)
end

function database.get_prefix(guild)
    return fetch_by_key_one(statements.prefix, "prefix", guild.id)
end

function database.get_suggestions_channel(guild)
    return fetch_by_key_one(statements.suggestions_channel, "id", guild.id)
end

function database.set_suggestions_channel(guild, channel)
    execute_statement(statements.set_suggestions_channel, guild.id, channel.id)
end

function database.remove_suggestions_channel(guild)
    execute_statement(statements.delete_suggestions_channel, guild.id)
end

function database.set_permission(guild, name, id)
    database.clear_permission(guild, name)
    execute_statement(statements.set_permission, guild.id, id, name)
end

function database.clear_permission(guild, name)
    execute_statement(statements.clear_permission, guild.id, name)
end

function database.set_bot_channels_enabled(guild, enabled)
    execute_statement(statements.set_bot_channels_enabled, guild.id, bool_to_number[enabled])
end

function database.add_bot_channel(guild, channel)
    database.remove_bot_channel(guild, channel)
    execute_statement(statements.add_bot_channel, guild.id, channel.id)
end

function database.remove_bot_channel(guild, channel)
    execute_statement(statements.remove_bot_channel, guild.id, channel.id)
end

function database.set_special_channel(guild, channel, name)
    database.clear_special_channel(guild, name)
    execute_statement(statements.set_special_channel, guild.id, channel.id, name)
end

function database.clear_special_channel(guild, name)
    execute_statement(statements.clear_special_channel, guild.id, name)
end

function database.get_arena_bans(guild)
    return fetch_by_key(statements.arena_bans, "id", guild.id)
end

function database.add_arena_ban(guild, member)
    execute_statement(statements.add_arena_ban, guild.id, member.id)
end

function database.remove_arena_ban(guild, member)
    execute_statement(statements.remove_arena_ban, guild.id, member.id)
end

function database.is_arena_banned(guild, member)
    return value_exists(statements.arena_banned, guild.id, member.id)
end

function database.set_rank_roles(guild, roles)
    database.clear_rank_roles(guild)

    for position, role in ipairs(roles) do
        execute_statement(statements.set_rank_role, guild.id, role.id, position)
    end 
end

function database.clear_rank_roles(guild)
    execute_statement(statements.clear_rank_roles, guild.id)
end

function database.get_rank_roles(guild)
    return fetch_by_key(statements.get_rank_roles, "id", guild.id)
end

function database.get_arena_player(guild, member)
    return fetch_dicts_one(statements.arena_player, guild.id, member.id)
end

function database.get_players_by_wins(guild)
    return fetch_dicts(statements.arena_players_by_wins, guild.id)
end

function database.get_players_by_elo(guild)
    return fetch_dicts(statements.arena_players_by_elo, guild.id)
end

function database.update_arena_player(guild, member, elo, wins, losses)
    execute_statement(statements.update_arena_player_rating, elo, wins, losses, guild.id, member.id)
end

function database.update_arena_player_wins(guild, member, wins)
    execute_statement(statements.update_arena_player_wins, wins, guild.id, member.id)
end

function database.arena_player_exists(guild, member)
    return value_exists(statements.arena_player_exists, guild.id, member.id)
end

function database.get_elo_config(guild)
    return fetch_dicts_one(statements.get_elo_config, guild.id)
end

function database.set_elo_config(guild, k_factor, scale)
    execute_statement(statements.set_elo_config, guild.id, k_factor, scale)
end

function database.get_special_channel(guild, name)
    return fetch_by_key_one(statements.get_special_channel, "id", guild.id, name)
end

function database.get_permissions(guild)
    return fetch_dicts(statements.get_permissions, guild.id)
end

function database.create_arena_player(guild, member, elo)
    execute_statement(statements.create_arena_player, guild.id, member.id, elo)
end

return database