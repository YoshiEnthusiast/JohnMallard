local data = {
    one_emoji = "1️⃣",
    two_emoji = "2️⃣",
    fire_emoji = "️‍🔥",
    ranks_count = 5
}

local current = {}

function data.get_current_arena(guild)
    return current[guild.id]
end

function data.add_arena(guild, arena)
    current[guild.id] = arena
end

function data.terminate_arena(arena)
    for id, item in pairs(current) do
        if item == arena then
            current[id] = nil
            break
        end
    end
end

return data

