local discordia = require("discordia")
local database = require("../db/database")

local thumbs_up = "👍"
local thumbs_down = "👎"

local suggestions = {}

local function put_reactions(msg)
    if msg.channel.id ~= database.get_suggestions_channel(msg.guild) then
        return
    end

    msg:addReaction(thumbs_up)
    msg:addReaction(thumbs_down)
end

function suggestions.init()
    discordia.storage.client:on("messageCreate", function(msg)
        if msg.guild == nil then
            return
        end
        
        put_reactions(msg)
    end)
end

return suggestions

