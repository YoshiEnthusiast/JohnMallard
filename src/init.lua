local discordia = require("discordia")
local config = require("./config")
local modules = require("./modules/allModules")

local client = discordia.Client()
discordia.storage.client = client

for _, module in ipairs(modules) do
    local init = module.init
    
    if init ~= nil then
        init()
    end
end

client:run("Bot " .. config.get_value("token"))