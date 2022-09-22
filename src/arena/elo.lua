local exponent_base = 10

local elo = {
    default_k_factor = 32,
    default_scale = 400,
    outcomes = {
        win = 1,
        draw = 0.5,
        loss = 0
    }
}

local function get_team_rating(team)
    local rating = 0

    for _, player in ipairs(team.players) do
        rating = rating + player.rating
    end

    return rating
end


function elo.RankingSystem(props)
    local ranking_system = {
        k_factor = props.k_factor or elo.default_k_factor,
        scale = props.scale or elo.default_scale
    }

    function ranking_system:get_winning_probability(team_one, team_two)
        local rating_difference = get_team_rating(team_two) - get_team_rating(team_one)
        local exponent = rating_difference / self.scale

        return 1 / (1 + exponent_base ^ exponent)
    end

    function ranking_system:get_draw_offset(team_one, team_two)
        local winning_probability = self:get_winning_probability(team_one, team_two)

        return math.abs(winning_probability - 0.5)
    end

    function ranking_system:get_updated_rating(rating, winning_probability, outcome)
        return rating + self.k_factor * (outcome - winning_probability)
    end

    function ranking_system:update_player_rating(player, winning_probability, outcome)
        player.rating = self:get_updated_rating(player.rating, winning_probability, outcome)
    end

    function ranking_system:update_team_rating(team_one, team_two, outcome)
        local team_one_win_probability = self:get_winning_probability(team_one, team_two)

        local team_two_win_probability = 1 - team_one_win_probability
        local team_two_outcome = 1 - outcome

        for _, player in ipairs(team_one.players) do
            self:update_player_rating(player, team_one_win_probability, outcome)
        end

        for _, player in ipairs(team_two.players) do
            self:update_player_rating(player, team_two_win_probability, team_two_outcome)
        end
    end

    return ranking_system
end

return elo