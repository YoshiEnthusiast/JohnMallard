local json = require("json")
local fs = require("fs")

local files = {}

function files.read(path)
    local file = io.open(path)

    if file == nil then
        return
    end

    local data = file:read("a")
    file:close()
    return data
end

function files.write(path, text)
    local file = io.open(path, "w")

    if file == nil then
        return
    end

    file:write(text)
    file:close()
end

function files.exists(path)
    return fs.existsSync(path)
end

function files.read_json(path)
    local data = files.read(path)

    if data == nil then
        return
    end

    return json.decode(data)
end

function files.write_json(object, path)
    local json = json.encode(object, {
        indent = true
    })

    files.write(path, json)
end

return files