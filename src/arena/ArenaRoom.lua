local data = require("./arenaData")

local function ArenaRoom(props)
    local team_one = props.team_one
    local team_two = props.team_two

    local forfeits = {}

    local arena_room = {
        channel = props.channel,
        message_id = props.message_id,
        emoji_to_team = {
            [data.one_emoji] = team_one,
            [data.two_emoji] = team_two
        },
        teams = {
            team_one,
            team_two
        },
        team_one = team_one,
        team_two = team_two,
    }

    function arena_room:all_players()
        local players = {}

        for _, team in ipairs(self.teams) do
            for _, player in ipairs(team.players) do
                table.insert(players, player)
            end
        end

        return players
    end

    function arena_room:get_another(team)
        for _, item in ipairs(self.teams) do
            if item ~= team then
                return item
            end
        end
    end

    function arena_room:player_by_id(id)
        for _, player in ipairs(self:all_players()) do
            if player.member.id == id then
                return player
            end
        end
    end

    function arena_room:register_forfeit(player)
        forfeits[player] = true
    end

    function arena_room:everyone_forfeited()
        for _, forfeited in pairs(forfeits) do
            if not forfeited then
                return false
            end
        end

        return true
    end

    for _, player in ipairs(arena_room:all_players()) do
        forfeits[player] = false
    end

    return arena_room
end

return ArenaRoom