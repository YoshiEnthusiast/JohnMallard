local discordia = require("discordia")
local http = require("coro-http")
local json = require("json")
local config = require("./config")

require("discordia-components")

local user_regex = "<@!?(%d+)>"
local role_regex = "<@&(%d+)>"
local channel_regex = "<#(%d+)>"

local not_white_space_regex = "[^%s]"
local first_lower_case_regex = "^%l"

local client = discordia.storage.client

local utils = {}

local function user_id_from_string(string)
    return string:match(user_regex)
end

local function add_parameter(url, name, value)
    return url .. name .. "=" .. value .. "&"
end

local function add_parameters(url, params)
    for _, param in ipairs(params) do
        url = add_parameter(url, param.name, param.value)
    end

    return url
end

local function construct_embed(args)
    local embed = {
        title = args.title,
        description = args.description,
        url = args.url,
        fields = args.fields,
        timestamp = args.timestamp,
        footer = args.footer,
        thumbnail = args.thumbnail
    }

    local image_url = args.image_url

    if image_url ~= nil then
        embed.image = {
            url = image_url
        }
    end

    local color = args.color

    if color ~= nil then
        embed.color = discordia.Color.fromHex(color).value
    end

    return embed
end

function utils.user_from_string(string)
    return client:getUser(user_id_from_string(string))
end

function utils.member_from_string(guild, string)
    return guild:getMember(user_id_from_string(string))
end

function utils.channel_from_string(string)
    return client:getChannel(string:match(channel_regex))
end

function utils.role_from_string(guild, string)
    return guild:getRole(string:match(role_regex))
end

function utils.starts_with(string, text)
    return string:sub(1, #text) == text
end

function utils.split(text, by)
    local result = {}
    local sep = "([^" .. by .. "]+)"

    for i in string.gmatch(text, sep) do
        table.insert(result, i)
    end

    return result
end

function utils.sub_table(table, from, to)
    local result = {}
    local pos = 1

    for i = from, to or #table do
        result[pos] = table[i]
        pos = pos + 1
    end

    return result
end

function utils.capital_letter(text)
    return text:sub(1, 1):upper()..text:sub(2, #text)
end

function utils.send_embed(query, args)
    return query.reply({
        embed = construct_embed(args)
    })
end

function utils.send_embed_channel(channel, args)
    return channel:send({
        embed = construct_embed(args)
    })
end

function utils.table_contains(table, value)
    for _, item in ipairs(table) do
        if item == value then 
            return true
        end
    end

    return false
end

function utils.index_of(table, value)
    for index, item in ipairs(table) do
        if item == value then 
            return index
        end
    end
end

function utils.remove_value(tbl, value)
    local index = utils.index_of(tbl, value)

    if index ~= nil then
        table.remove(tbl, index)
        return true
    end

    return false
end

function utils.search_image(tag)
    local search_url = config.get_value("searchurl")
    local search_engine_id = config.get_value("searchengineid")
    local google_api_key = config.get_value("googleapikey")

    if search_url == nil or search_engine_id == nil or google_api_key == nil then
        return nil, "Missing search details"
    end

    local url = add_parameters(search_url, {
        {
            name = "q",
            value = tag
        },
        {
            name = "searchType",
            value = "image"
        },
        {
            name = "start",
            value = math.random(99)
        },
        {
            name = "num",
            value = 1
        },
        {
            name = "cx",
            value = search_engine_id
        },
        {
            name = "key",
            value = google_api_key
        }
    })

    local _, body = http.request("GET", url)
    local data = json.decode(body)
    local images = data["items"]

    return images[1]["link"]
end

function utils.clamp(value, min, max)
    value = math.max(value, min)

    return math.min(value, max)
end

function utils.get_full_name(user)
    return user.name .. "#" .. user.discriminator
end

function utils.find_not_white_space(text, init)
    return text:find(not_white_space_regex, init)
end

function utils.get_iterator_count(iterator)
    local count = 0

    while iterator() ~= nil do
        count = count + 1
    end

    return count
end

function utils.quote(text)
    return "\"" .. text .. "\""
end

function utils.make_bold(text)
    return "**" .. text .. "**"
end

function utils.first_to_upper(text)
    return text:gsub(first_lower_case_regex, string.upper)
end

function utils.distinct(array)
    local result = {}
    local hash = {}

    for _, item in ipairs(array) do
        if not hash[item] then
            table.insert(result, item)
            hash[item] = true
        end
    end

    return result
end

function utils.select(array, predicate)
    local result = {}

    for _, item in ipairs(array) do
        local value = predicate(item)

        table.insert(result, value)
    end

    return result
end

function utils.where(array, predicate)
    local result = {}
    
    for _, item in ipairs(array) do
        if predicate(item) then
            table.insert(result, item)
        end
    end

    return result
end

function utils.concat_with_comas(values)
    return table.concat(values, ", ")
end

function utils.copy(array)
    local result = {}

    for _, item in ipairs(array) do
        table.insert(result, item)
    end

    return result
end

function utils.put_in_brackets(text)
    return "(" .. text .. ")"
end


function utils.build_table(objects)
    local fields = {}

    for _, object in ipairs(objects) do
        for _, prop in ipairs(object) do
            local name = prop.name

            local fields_by_name = utils.where(fields, function(field)
                return field.name == name
            end)

            local value = prop.value

            if #fields_by_name <= 0 then
                table.insert(fields, {
                    name = name,
                    value = value,
                    inline = true
                })
            else
                local field = fields_by_name[1]

                field.value = field.value .. "\n" .. value
            end
        end
    end

    return fields
end

function utils.add_pages_menu(reply, pages)
    if reply == nil or #pages < 1 then
        return
    end

    local options = {}

    for index, page in ipairs(pages) do
        local option = {
            label = page.name,
            value = tostring(index)
        }

        table.insert(options, option)
    end

    local menu = discordia.SelectMenu({
        id = "menu",
        placeholder = "Select_page",
        options = options
    })

    local components = discordia.Components({
        menu
    })

    reply:setComponents(components)

    while true do
        local success, interaction = reply:waitComponent()
    
        if not success then 
            break
        end
    
        local index = tonumber(interaction.data.values[1])
    
        interaction:update({
            components = components,
            embed = pages[index].content
        })
    end
end

function utils.send_pages_menu_buttons(query, pages)
    local length = #pages

    if length < 1 then
        return
    end

    local reply = utils.send_embed(query, pages[1])

    if reply == nil or length < 2 then
        return
    end

    local Button = discordia.Button
    local Components = discordia.Components

    local style = "success"

    local previous = Button({
        id = "prev",
        label = "<<",
        style = style,
        disabled = true
    })

    local next = Button({
        id = "next",
        label = ">>",
        style = style
    })

    local buttons = {
        previous,
        next
    }

    local index = 1

    reply:setComponents(Components(buttons))

    while true do
        local success, interaction = reply:waitComponent()

        if not success then
            break
        end

        local id = interaction.data.custom_id

        if id == "prev" then
            index = index - 1

            if index <= 1 then
                previous:disable()
            end

            next:enable()
        elseif id == "next" then
            index = index + 1

            if index >= length then
                next:disable()
            end

            previous:enable()
        end

        interaction:update({
            components = discordia.Components(buttons),
            embed = pages[index]
        })
    end
end

function utils.make_inline(fields)
    for _, field in ipairs(fields) do
        field.inline = true
    end
end

function utils.name_by_id(id)
    local user = client:getUser(id)

    if user ~= nil then
        return utils.get_full_name(user)
    end

    return id
end

return utils