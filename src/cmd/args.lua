local discordia = require("discordia")
local utils = require("../utils")

require("discordia-slash")

local option_types = discordia.enums.appCommandOptionType

local type_names = {
    [option_types.boolean] = "boolean",
    [option_types.channel] = "channel",
    [option_types.user] = "member",
    [option_types.integer] = "number",
    [option_types.string] = "string",
    [option_types.role] = "role"
}

local text_to_bool = {
    ["true"] = true,
    ["false"] = false
}

local function Arg(props)
    local arg = {
        name = props.name,
        type = props.type,
        optional = props.optional,
        parse = props.parse,
        ignore_spaces = props.ignore_spaces,
    }

    function arg:get_demo_string()
        local name = self.name

        if self.optional then
            return "[" .. name .. "]"
        end

        return "(" .. name .. ")"
    end

    function arg:should_ignore_spaces()
        return self.ignore_spaces and self.type == option_types.string
    end

    function arg:get_convertsion_error(text)
        return "Could not convert " .. text .. " to a " .. type_names[self.type] .. " value"
    end

    function arg:get_does_not_exist_error(text)
        return utils.capital_letter(type_names[self.type]) .. " " .. text .. " does not exist"
    end

    return arg
end

local function Bool(props)
    props.type = option_types.boolean

    props.parse = function(self, text, query, result)
        local bool = text_to_bool[text]

        if bool ~= nil then
            result.value = bool
        else
            result.error = self:get_convertsion_error(text)
        end
    end

    return Arg(props)
end

local function Channel(props)
    props.type = option_types.channel

    props.parse = function(self, text, query, result)
        local channel = utils.channel_from_string(text)

        if channel ~= nil then
            result.value = channel
        else
            result.error = self:get_does_not_exist_error(text)
        end
    end

    return Arg(props)
end

local function Member(props)
    props.type = option_types.user

    props.parse = function(self, text, query, result)
        local user = utils.member_from_string(query.guild, text)

        if user ~= nil then
            result.value = user
        else
            result.error = self:get_does_not_exist_error(text)
        end
    end

    return Arg(props)
end

local function Number(props)
    props.type = option_types.integer

    props.parse = function(self, text, query, result)
        local number = tonumber(text)

        if number ~= nil then
            result.value = number
        else
            result.error = self:get_convertsion_error(text)
        end
    end

    return Arg(props)
end

local function String(props)
    props.type = option_types.string

    props.parse = function(self, text, query, result)
        result.value = text
    end

    return Arg(props)
end

local function Role(props)
    props.type = option_types.role

    props.parse = function(self, text, query, result)
        local role = utils.role_from_string(query.guild, text)

        if role ~= nil then 
            result.value = role
        else
            result.error = self:get_does_not_exist_error(text)
        end
    end
    
    return Arg(props)
end

local args = {
    Bool = Bool,
    Channel = Channel,
    Member = Member,
    Number = Number,
    String = String,
    Role = Role
}

return args