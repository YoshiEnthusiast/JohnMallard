local discordia = require("discordia")
local commands = require("../cmd/commands")
local processor = require("./commandProcessor")

require("discordia-slash")

local slash_commands = {}

function slash_commands.init()
    local client = discordia.storage.client
    
    client:useApplicationCommands()

    client:on("ready", function()
        client.guilds:forEach(function(guild)
            for _, command in ipairs(commands) do
                if not command.prefix_only then
                    local options = {}
                    
                    for _, arg in ipairs(command.args) do
                        local name = arg.name
                        local option = {
                            name = name,
                            description = arg.description or name,
                            type = arg.type,
                            required = not arg.optional
                        }
                        
                        table.insert(options, option)
                    end

                    client:createGuildApplicationCommand(guild.id, {
                        name = command.name,
                        description = command.description,
                        type = discordia.enums.appCommandType.chatInput,
                        options = options,
                        default_permission = 1
                    })
                end
            end
        end)
    end)

    client:on("slashCommand", function(interaction, slash_command, args)
        for _, command in ipairs(commands) do
            if command.name == slash_command.name then
                local author = interaction.user
                local channel = interaction.channel

                local can_run, error_message = processor.can_run_command(channel, author, command)

                if not can_run then
                    if error_message ~= nil then
                        interaction:reply(error_message)
                    end

                    return
                end

                local query = {
                    author = author,
                    channel = channel,
                    interaction = interaction,
                    guild = interaction.guild,
                    member = interaction.member
                }

                function query.reply(content)
                    local reply = interaction:reply(content)
                    
                    if type(reply) ~= "table" then
                        reply = interaction:getReply()
                    end

                    return reply
                end

                command.execute(query, args or {})

                break
            end
        end
    end)
end

return slash_commands