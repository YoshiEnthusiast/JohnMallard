local function get_required_args_count(command)
    local result = 0

    for _, arg in ipairs(command.args) do
        if arg.optional then
            break
        else
            result = result + 1
        end
    end

    return result
end

local function Command(props)
    local command = {
        name = props.name:lower(),
        args = props.args or {},
        execute = props.execute,
        requirement = props.requirement,
        description = props.description,
        section = props.section,
        special_channel = props.special_channel,
        is_arena_room_command = props.is_arena_room_command,
        prefix_only = props.prefix_only
    }

    function command:run(query, passed_args)
        local required_args_count = get_required_args_count(self)
        local passed_args_count = #passed_args

        if passed_args_count < required_args_count or passed_args_count > #self.args then
            query.reply("Command " .. self.name .. " doesn't take " .. passed_args_count .. " arguments")
            return
        end

        local parsed_args = {}

        for i, passed_arg in ipairs(passed_args) do
            local result = {}
            local arg = self.args[i]
            arg:parse(passed_arg, query, result)
            local error = result.error

            if error ~= nil then
                query.reply("Error parsing argument " .. arg.name .. "(" .. i .. "): " .. error)
                return
            end

            parsed_args[arg.name] = result.value
        end

        self.execute(query, parsed_args)
    end

    function command:get_demo_string()
        local parts = {
            self.name
        }

        for _, arg in ipairs(self.args) do
            table.insert(parts, arg:get_demo_string())
        end
        
        return table.concat(parts, " ")
    end

    return command
end

return Command