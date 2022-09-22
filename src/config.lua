local files = require("./files")

local data = files.read_json("config.json")

local config = {
    default_prefix = "-",
    special_channels = {
        "arenainfo",
        "arenachat"
    }
}

function config.get_value(name)
    return data[name]
end

return config