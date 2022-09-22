local utils = require("../utils")

local put_in_brackets = utils.put_in_brackets

local builder = {
    question_mark = "?",
    order = {
        ascending = "ASC",
        descending = "DESC"
    }
}

local function to_string(value)
    local type = type(value)

    if type == "string" then
        return value
    elseif type == "table" then
        return utils.concat_with_comas(value)
    end

    return ""
end

local function to_string_brackets(value)
    return put_in_brackets(to_string(value))
end

local function pair_to_string(pair)
    local value = pair.value or builder.question_mark

    return pair.name .. " = " .. value
end

local function concatenate_pairs(pairs)
    local string_values = utils.select(pairs, function(pair)
        local type = type(pair)
        local value 

        if type == "string" then
            value = {
                name = pair
            }
        else
            value = pair
        end

        return pair_to_string(value)
    end)

    return table.concat(string_values, " AND ")
end

local function Statement()
    local statement = {
        value = ""
    }

    function statement:select(what, from)
        self:append_many({
            "SELECT",
            to_string(what),
            "FROM",
            from
        })

        return self
    end 

    function statement:insert(into, values)
        self:append_many({
            "INSERT INTO",
            into, 
            "VALUES",
            to_string_brackets(values)
        })

        return self
    end

    function statement:where(pairs)
        self:append_many({
            "WHERE",
            concatenate_pairs(pairs)
        })

        return self
    end

    function statement:update(what, pairs)
        self:append_many({
            "UPDATE",
            what,
            "SET",
            concatenate_pairs(pairs)
        })

        return self
    end

    function statement:delete(from)
        self:append_many({
            "DELETE FROM",
            from
        })

        return self
    end

    function statement:on_conflict(with)
        self:append_many({
            "ON CONFLICT",
            to_string_brackets(with),
            "DO"
        })

        return self
    end

    function statement:exists(sub_statement)
        self:append_many({
            "SELECT EXISTS",
            put_in_brackets(sub_statement.value)
        })

        return self
    end

    function statement:limit(count)
        self:append_many({
            "LIMIT",
            count
        })

        return self
    end

    function statement:order_by(what, order)
        self:append_many({
            "ORDER BY",
            what
        })

        if order ~= nil then
            self:append(order)
        end

        return self
    end

    function statement:append(text)
        local value = self.value

        if value == "" then
            self.value = text
            return
        end
        
        self.value = self.value .. " " .. text
    end

    function statement:append_many(values)
        for _, value in ipairs(values) do
            self:append(value)
        end
    end

    return statement
end

function builder.get_question_marks(count)
    local question_marks = {}

    for i = 1, count do
        table.insert(question_marks, builder.question_mark)
    end

    return table.unpack(question_marks)
end

function builder.select(what, from)
    return Statement():select(what, from)
end

function builder.insert(into, values)
    return Statement():insert(into, values)
end

function builder.update(what, pairs)
    return Statement():update(what, pairs)
end

function builder.delete(from)
    return Statement():delete(from)
end

function builder.exists(sub_statement)
    return Statement():exists(sub_statement)
end

return builder