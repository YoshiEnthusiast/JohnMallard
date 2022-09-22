local utils = require("./utils")
local database = require("./db/database")

local permissions = {
    all = {
        "admin",
        "mod",
        "to"
    }
}

local function id_by_name(permissions, name)
    for _, permission in ipairs(permissions) do
        if permission["permission_name"] == name then
            return permission["id"]
        end
    end
end

function permissions.get_all_roles(guild)
    local roles = {}

    for _, permission in ipairs(database.get_permissions(guild)) do
        local role = guild:getRole(permission["id"])

        if role ~= nil then
            table.insert(roles, role)
        end
    end

    return roles
end

function permissions.has_permission(guild, user, permission)
    if guild.ownerId == user.id then 
        return true
    elseif permission == "owner" then 
        return false
    end

    local all_permissions = permissions.all
    local index = utils.index_of(all_permissions, permission)

    if index == nil then
        return false
    end

    local member = guild:getMember(user.id)
    local permissions = database.get_permissions(guild)

    local json = require("json")
    print(json.encode(permissions, {
        indent = true
    }))

    for i = 1, index do
        local permission_name = all_permissions[i]
        local id = id_by_name(permissions, permission_name)

        if id ~= nil and member:hasRole(id) then
            return true
        end
    end

    return false
end

function permissions.has_permission_roles(guild, member)
    if guild.ownerId == member.id then 
        return true
    end

    local permissions = database.get_permissions(guild)

    for _, permission in ipairs(permissions) do
        if member:hasRole(permission["id"]) then
            return true
        end
    end

    return false
end

return permissions