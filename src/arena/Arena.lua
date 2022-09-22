local utils = require("../utils")
local permissions = require("../permissions")
local data = require("./arenaData")
local elo = require("./elo")
local database = require("../db/database")
local Room = require("./ArenaRoom")

local log_colors = {
    green = "#41b80f",
    red = "#de0d0d",
    blue = "#0f7cb8",
    yellow = "#edc821"
}

local initial_elo = 1000
local rank_rating_interval = 50

local function allow_read_messages(channel, object)
    channel:getPermissionOverwriteFor(object):allowPermissions("readMessages")
end

local function allow_read_messages_team(channel, team)
    for _, player in ipairs(team.players) do
        allow_read_messages(channel, player.member)
    end
end

local function get_team_mention(team)
    local mentions = utils.select(team.players, function(player)
        return player.member.mentionString
    end)

    return utils.concat_with_comas(mentions)
end

local function get_team_name(team, ignore)
    local players = utils.where(team.players, function(player)
        return player ~= ignore
    end)

    local names = utils.select(players, function(player)
        return player.name
    end)

    return utils.concat_with_comas(names)
end

local function disable_team(team)
    team.active = false

    for _, player in ipairs(team.players) do
        player.active = false
    end
end

local function Arena(props)
    local log_channel = props.log_channel
    local guild = log_channel.guild

    local arena = {
        name = props.name,
        log_channel = log_channel,
        guild = guild,
        players_per_team = math.max(props.players_per_team, 1),
        teams = {},
        rooms = {},
        team_requests = {},
        ranking_system = elo.RankingSystem({
            database.get_elo_config(guild) or {}
        })
    }

    function arena:update()
        if not self.active then
            return
        end

        local teams = self:get_active_teams()

        for _, team in ipairs(teams) do
            local enemies = utils.copy(teams)
            local ranking_system = self.ranking_system

            table.sort(enemies, function(team_one, team_two)
                return ranking_system:get_draw_offset(team, team_one) < ranking_system:get_draw_offset(team, team_two)
            end)

            for _, enemy_team in ipairs do
                if team ~= enemy_team and team.room == nil and enemy_team.room == nil and team.last_played_with ~= enemy_team then
                    local log_channel = self.log_channel
                    local team_name = team.name
                    local enemy_name = enemy_team.name

                    local room_channel = log_channel.category:createTextChannel(team_name .. "-vs-" .. enemy_name)
                    local guild = self.guild

                    room_channel:getPermissionOverwriteFor(guild.defaultRole):denyPermissions("readMessages")

                    allow_read_messages_team(room_channel, team)
                    allow_read_messages_team(room_channel, enemy_team)

                    for _, role in ipairs(permissions.get_all_roles(guild)) do
                        allow_read_messages(room_channel, role)
                    end

                    local one = data.one_emoji
                    local two = data.two_emoji

                    local message = room_channel:send(get_team_mention(team) .. " and " .. get_team_mention(enemy_team) .. ", you are up against each other. Click on the corresponding reaction to report the winner: \n" .. one .. " — " .. team_name .. "\n" .. two .. " — " .. enemy_name)
                    message:addReaction(one)
                    message:addReaction(two)

                    local room = Room({
                        channel = room_channel,
                        message_id = message.id,
                        team_one = team,
                        team_two = enemy_team
                    })

                    table.insert(self.rooms, room)

                    team.room = room
                    team.last_played_with = enemy_team
                    enemy_team.room = room
                    enemy_team.last_played_with = team
                end
            end
        end
    end

    function arena:start(query)
        if self.active then
            query.reply("Arena has already been started")
            return
        elseif self.started then
            query.reply("Arena has already been stopped")
            return
        end

        local message = "Arena"..utils.quote(self.name).."started"
        query.reply(message)
        self:log(message, log_colors.blue)
        
        self.active = true
        self.started = true

        self:update()
    end

    function arena:stop(query)
        if self.started and not self.active then
            query.reply("Arena has already been stopped")
            return
        end

        self.active = false
        local message = "Arena has been stopped. Final results will be available as soon as everyone finishes their games"

        query.reply(message)
        self:log(message, log_colors.blue)

        self:check_terminate()
    end

    function arena:add_player(query)
        local member = query.member

        if self:member_banned(member) then
            query.reply("You cannot join because you are banned")
            return
        end

        if not self.active and self.started then
            query.reply("You cannot join because the arena has been stopped")
            return
        end

        local current_team = self:team_by_member(member)

        if self:teams_enabled() then
            if current_team == nil then
                query.reply("You need to have a team to join")
                return
            end

            local players_per_team = self.players_per_team

            if #current_team.players < players_per_team then
                query.reply("You need to have a total of " .. players_per_team .. " players in your team to be able to join")
                return
            end

            local player = self:player_by_member(member)

            if player.active then
                query.reply("You have already joined")
                return 
            end

            player.active = true

            self:on_team_member_joined(query, current_team, player)
        else
            if current_team == nil then
                local new_team = self:create_team({
                    self:create_player(member)
                })

                table.insert(self.teams, new_team)

                self:activate_team_reply_to_query(query, new_team)
            else
                if current_team.active then
                    query.reply("You have already joined")
                    return
                end

                self:activate_team_reply_to_query(query, current_team)
            end
        end
    end

    function arena:on_team_member_joined(query, team, player)
        for _, member in ipairs(team.players) do
            if not member.active then 
                self:log(player.name .. " joined")
                query.reply("You have joined the arena. Waiting for other team members")

                return
            end
        end

        self:activate_team_reply_to_query(query, team)
    end

    function arena:activate_team_reply_to_query(query, team)
        team.active = true

        self:log(get_team_name(team) .. " joined")

        query.reply("You have joined the arena")
    end

    function arena:remove_player(query)
        local member = query.member
        local team = self:team_by_member(member)

        print(team)

        if team == nil or not team.active then
            query.reply("You are not currently in the arena")
            return
        end

        local player = self:player_by_member(member)
        local name = player.name

        local message = name .. ", you have left the arena"
        local log

        if self:teams_enabled() then
            message = message .. ". All of your team will need to join to continue playing"
            log = get_team_name(team) .. " left"
        else
            log = name .. " left"
        end

        disable_team(team)

        query.reply(message)
        self:log(log, log_colors.red)
    end

    function arena:register_forfeit(query)
        local room = self:room_by_query(query)

        if room == nil then
            return
        end
        
        local member = query.member

        if permissions.has_permission_roles(self.guild, member) then
            self:forfeit(room)
            return
        end

        local player = room:player_by_id(member.id)
        room:register_forfeit(player)

        if room:everyone_forfeited() then
            query.reply("Match skipped")
            self:forfeit(room)
        else
            query.reply(player.name .. " wants so skip the match. Use " .. utils.quote("forfeit") .. " command if you agree")
        end
    end

    function arena:forfeit(room)
        self:log(get_team_name(room.team_one) .. " and " .. get_team_name(room.team_two) .. " forfieted", log_colors.blue)
        self:close_room(room)
    end

    function arena:on_reaction_added(reaction)
        local message = reaction.message

        for _, room in ipairs(self.rooms) do
            if room.message_id == message.id then
                local team = room.emoji_to_team[reaction.emojiName]

                if team ~= nil then
                    local voters = reaction:getUsers():findAll(function(user)
                        return room:player_by_id(user.id) ~= nil
                    end)

                    if utils.get_iterator_count(voters) >= self.players_per_team * 2 then
                        self:on_team_won(room, team)
                    end
                end

                break
            end
        end
    end

    function arena:determine_host(query)
        local room = self:room_by_query(query)

        if room == nil then
            return
        end

        if room.host_determined then
            query.reply("Host has already been determined")
            return
        end

        local players = room:all_players()
        local host = players[math.random(#players)]

        query.reply(host.member.user.mentionString .. " hosts")

        room.host_determined = true
    end

    function arena:on_team_won(room, winner)
        local winstreak = winner.winstreak
        local wins = winner.wins

        if winstreak >= 2 then
            winner.wins = wins + 2
        else
            winner.wins = wins + 1
        end

        local loser = room:get_another(winner)
        local outcome = elo.outcomes.win

        self.ranking_system:update_team_rating(winner, loser, outcome)
        self:update_team_rating(winner, outcome)
        self:update_team_rating(loser, outcome)

        winner.winstreak = winstreak + 1
        loser.winstreak = 0

        self:log(get_team_name(winner) .. " beat " .. get_team_name(loser), log_colors.blue)

        self:close_room(room)
    end

    function arena:update_team_rating(team, outcome)
        local guild = self.guild

        for _, player in ipairs(team.players) do
            local member = player.member
            local player_data = database.get_arena_player(guild, member)

            if player_data ~= nil then
                local value

                if outcome == elo.outcomes.win then
                    value = "wins"
                else
                    value = "losses"
                end

                self:increment_player_value(player_data, value)

                local rating = player.rating

                local index = self:get_rank_index(rating)
                local rank_roles_ids = database.get_rank_roles(guild)

                local role_id = rank_roles_ids[index]

                if not member:hasRole(role_id) then
                    for _, id in ipairs(rank_roles_ids) do
                        member:removeRole(id)
                    end

                    member:addRole(role_id)
                end

                database.update_arena_player(guild, member, rating, player_data["wins"], player_data["losses"])
            end
        end
    end

    function arena:get_rank_index(rating)
        if rating <= initial_elo then
            return 1
        end

        local ranks_count = data.ranks_count

        return math.min(math.ceil((rating - initial_elo) / rank_rating_interval), ranks_count)
    end

    function arena:increment_player_value(player, value)
        player[value] = player[value] + 1
    end

    function arena:close_room(room)
        for _, team in ipairs(room.teams) do
            team.room = nil
        end

        room.channel:delete()
        utils.remove_value(self.rooms, room)

        if not self.active then
            self:check_terminate()
            return
        end

        self:update()
    end

    function arena:check_terminate()
        if #self.rooms <= 0 then
            self:log("Arena " .. utils.quote(self.name) .. " has ended", log_colors.blue)
            utils.send_embed_channel(self.log_channel, self:get_scores_embed())
            data.terminate_arena(self)
        end
    end

    function arena:get_scores_embed()
        local teams = self.teams

        table.sort(teams, function(team, another)
            local wins_one = team.wins
            local wins_two = another.wins

            if wins_one == wins_two then
                return team.winstreak > another.winstreak
            end

            return wins_one > wins_two
        end)

        local description

        if #teams > 0 then
            description = ""

            for place, team in ipairs(teams) do
                local points
                local wins = team.wins

                if team.winstreak >= 2 then
                    points = data.fire_emoji .. wins
                else
                    points = wins
                end

                local element = table.concat({ 
                    "**" .. place .. ".**",
                    get_team_name(team), 
                    points
                }, " ")
                
                description = description .. element .. "\n"
            end
        else
            description = "No scores yet!"
        end

        return {
            title = "Arena " .. utils.quote(self.name) .. " scores",
            description = description,
            color = log_colors.yellow
        }
    end

    function arena:send_scores(query)
        utils.send_embed(query, self:get_scores_embed())
    end

    function arena:send_info(query)
        local ranking_system = self.ranking_system

        local fields = utils.make_inline({
            {
                name = "Name",
                value = self.name
            },
            {
                name = "Players per team",
                value = self.players_per_team
            },
            {
                name = "Total teams",
                value = #self.teams
            },
            {
                name = "Active teams",
                value = #self:get_active_teams()
            },
            {
                name = "Elo k-factor",
                value = ranking_system.k_factor
            },
            {
                name = "Elo scale",
                value = ranking_system.scale
            }
        })

        utils.send_embed(query, {
            title = "Arena info",
            fields = fields
        })
    end

    function arena:log(message, color)
        utils.send_embed_channel(self.log_channel, {
            title = message,
            color = color
        })
    end

    function arena:get_active_teams()
        local teams = {}

        for _, team in ipairs(self.teams) do
            if team.active then
                table.insert(teams, team)
            end
        end

        return teams
    end

    function arena:is_arena_room(channel)
        for _, room in ipairs(self.rooms) do
            if room.channel.id == channel.id then
                return true
            end
        end

        return false
    end

    function arena:set_team_score(query, member, score)
        local team = self:team_by_member(member)

        if team == nil then
            local message

            if self:teams_enabled() then
                message = "This user does not belong to any team"
            else
                message = "This user hasn't joined the arena"
            end
            
            query.reply(message)
            return
        end

        team.wins = math.max(score, 0)
        query.reply(get_team_name(team) .. " now has the score of " .. team.wins)
    end

    function arena:on_member_banned(member)  
        local team = self:team_by_member(member)
        local name 

        if team ~= nil then
            name = self:player_by_member(member).name
            
            local room = team.room
            
            if room ~= nil then
                self:close_room(room)
            end
            
            disable_team(team)  
        else
            name = utils.get_full_name(member.user)
        end

        self:clear_member_requests(member)
        self:log("Member " .. name .. " banned", log_colors.red)
    end

    function arena:on_member_unbanned(member)
        self:log(utils.get_full_name(member) .. " unbanned", log_colors.green)
    end

    function arena:room_by_query(query)
        for _, room in ipairs(self.rooms) do
            if room.channel.id == query.channel.id then
                return room
            end
        end
    end

    function arena:send_team_request(query, member)
        if not self:check_teams_enabled(query) then
            return
        end

        if self:member_banned(member) then
            query.reply("You cannot send team requests because you are banned")
            return
        end

        local sender = query.member

        if sender == member then
            query.reply("You cannot send team request to yourself")
            return
        end

        local current_team = self:team_by_member(sender)

        if current_team ~= nil then
            if current_team.active then
                query.reply("You have to leave the arena to manage your team")
                return
            else 
                local player = self:player_by_member(member)

                if player ~= nil and utils.table_contains(current_team.players, player) then
                    query.reply("This player is already in your team")
                    return
                end
            end
        end

        local requests = self.team_requests[sender]

        if requests == nil then
            self.team_requests[sender] = {}
        elseif utils.table_contains(requests, member) then
            query.reply("This player has already got a team request from you")
            return
        end

        table.insert(self.team_requests[sender], member)
        query.reply("Team request sent from " .. sender.user.mentionString .. " to " .. member.user.mentionString)
    end

    function arena:accept_team_request(query, request_sender)
        if not self:check_teams_enabled(query) then
            return
        end

        local joining_member = query.member

        if self:member_banned(joining_member) then
            query.reply("You cannot accept team requests because you are banned")
            return
        end

        if joining_member == request_sender then
            query.reply("You cannot accept requests from yourself")
            return
        end

        if self:team_by_member(joining_member) ~= nil then
            query.reply("You need to leave you current team to join another one")
            return
        end

        local requests = self.team_requests
        local sent_requests = requests[request_sender]

        if sent_requests == nil or not utils.table_contains(sent_requests, joining_member) then
            query.reply("This member hasn't sent you a request")
            return
        end

        local team = self:team_by_member(request_sender)
        local joining_player = self:create_player(joining_member)

        local request_sender_player

        if team == nil then
            request_sender_player = self:create_player(request_sender)

            local new_team = self:create_team({
                request_sender_player,
                joining_player
            })

            table.insert(self.teams, new_team)
        else
            local players = team.players
            request_sender_player = self:player_by_member(request_sender)
            local name = request_sender_player.name

            if team.active then
                query.reply(name .. "'s team is already in game")
                return
            elseif #players >= self.players_per_team then
                query.reply(name .. "'s team already has the maximum number of players")
                return
            end

            table.insert(players, self:create_player(joining_player))
        end

        local requests = self.team_requests[request_sender]

        if requests ~= nil then
            utils.remove_value(requests, joining_member)
        end

        self:clear_member_requests(joining_member)

        query.reply("Joined " .. request_sender_player.name .. "'s team")
    end

    function arena:leave_team(query)
        if not self:check_teams_enabled(query) then
            return
        end

        local team = self:team_by_member(query.member)

        if team == nil then
            query.reply("You are not currently a member of any team")
            return
        end
        
        query.reply("You have left your team")
        self:log("Team" .. get_team_name(team) .. "disbanded")
        
        local room = team.room
        
        if room ~= nil then
            self:close_room(room)
        end
        
        utils.remove_value(self.teams, team)
    end

    function arena:display_requests(query)
        if not self:check_teams_enabled(query) then
            return
        end

        local sent_requests_display
        local recieved_requests_display

        local no_requests_message = "This list is empty!"

        local member = query.member
        local sent_requests = self.team_requests[member]

        if sent_requests == nil or #sent_requests < 1 then
            sent_requests_display = no_requests_message
        else
            local senders_names = utils.select(sent_requests, function(sender)
                return utils.get_full_name(sender.user)
            end)

            sent_requests_display = utils.concat_with_comas(senders_names)
        end

        local recieved_requests = self:get_recieved_requests_string(member)

        if recieved_requests == "" then
            recieved_requests_display = no_requests_message
        else
            recieved_requests_display = no_requests_message
        end

        local fields = {
            {
                name = "Sent:",
                value = sent_requests_display
            },
            {
                name = "Recieved:",
                value = recieved_requests_display
            }
        }

        utils.send_embed(query, {
            title = utils.get_full_name(member.user) .. "'s requests",
            fields = fields
        })
    end

    function arena:display_current_team(query)
        if not self:check_teams_enabled(query) then
            return
        end

        local member = query.member
        local team = self:team_by_member(member)

        if team == nil then
            query.reply("You do not belong to any team")
            return
        end

        local player = self:player_by_member(member)

        utils.send_embed(query, {
            title = player.name .. "'s teammates:",
            description = get_team_name(team, player)
        })
    end

    function arena:get_recieved_requests_string(member)
        local requests = {}

        for sender, recievers in pairs(self.team_requests) do
            if sender ~= member then
                for _, reciever in ipairs(recievers) do
                    if reciever == member then
                        table.insert(requests, utils.get_full_name(sender.user))

                        break
                    end
                end
            end
        end

        return utils.concat_with_comas(requests)
    end

    function arena:clear_requests(query)
        if not self:check_teams_enabled(query) then
            return
        end

        self:clear_member_requests(query.member)
        query.reply("Your requests have been cleared")
    end

    function arena:clear_member_requests(member)
        self.team_requests[member] = nil
    end

    function arena:create_player(member)
        local player = {
            name = utils.get_full_name(member.user),
            member = member
        }

        local guild = self.guild
        local player_data = database.get_arena_player(guild, member)

        if player_data == nil then
            database.create_arena_player(guild, member, initial_elo)
            player.rating = initial_elo
        else
            player.rating = player_data["elo"]
        end

        return player
    end

    function arena:member_banned(member)
        return database.is_arena_banned(self.guild, member)
    end

    function arena:create_team(players)
        local team = {
            players = players,
            score = 0,
            winstreak = 0
        }

        return team
    end

    function arena:teams_enabled()
        return self.players_per_team > 1
    end

    function arena:check_teams_enabled(query)
        if not self:teams_enabled() then
            query.reply("Teams are not enabled in this arena")
            return false
        end

        return true
    end

    function arena:team_by_member(member)
        for _, team in ipairs(self.teams) do
            for _, player in ipairs(team.players) do
                if player.member == member then
                    return team
                end
            end
        end
    end

    function arena:player_by_member(member)
        for _, team in ipairs(self.teams) do
            for _, player in ipairs(team.players) do
                if player.member == member then
                    return player
                end
            end
        end
    end

    arena:log("Arena " .. utils.quote(arena.name) .. " has been created", log_colors.blue)

    return arena
end

return Arena