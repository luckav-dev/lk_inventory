local Config = require 'config.config'

--- Inventory action logging. Always fires the `lk_inv:log` event so external
--- loggers/anti-cheats can consume it; optionally prints to console and posts a
--- Discord embed. Categories can be toggled in config.
local Logs = {}

-- Newest-first ring buffer of recent entries for the in-game audit panel.
local recent = {}

local function playerName(source)
    if not source or source == 0 then return 'system' end
    return ('%s (%s)'):format(GetPlayerName(source) or '?', source)
end

--- @return table[] newest-first { category, player, message, time }
function Logs.recent()
    return recent
end

--- @param category string  drop|give|buy|craft|frisk|dumpster|money|stash|...
--- @param source integer|nil
--- @param message string
--- @param extra table|nil  structured details for external consumers
function Logs.action(category, source, message, extra)
    if not Config.logs.enabled then return end
    if Config.logs.categories[category] == false then return end

    -- External hook (never collides — other resources opt in).
    TriggerEvent('lk_inv:log', category, source, message, extra)

    -- Keep a capped, newest-first buffer for the audit panel.
    table.insert(recent, 1, {
        category = category,
        player = playerName(source),
        message = message,
        time = os.date('%H:%M:%S'),
    })
    while #recent > (Config.auditBuffer or 200) do
        table.remove(recent)
    end

    if Config.logs.console then
        print(('^5[lk_inv:%s]^0 %s — %s'):format(category, playerName(source), message))
    end

    local webhook = Config.logs.webhook
    if webhook and webhook ~= '' then
        PerformHttpRequest(webhook, function() end, 'POST', json.encode({
            username = 'LK Inventory',
            embeds = { {
                title = ('Inventory · %s'):format(category),
                description = ('**%s**\n%s'):format(playerName(source), message),
                color = 3447003,
                footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
            } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

return Logs
