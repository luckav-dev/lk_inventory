local Config = require 'config.dumpsters'
local Locale = require 'shared.locale'
local Client = require 'client.main'

--- Searchable dumpsters: walk up to one of the configured props and press the
--- key to rummage for random loot (server-generated, with a cooldown).

local hashes = {}
for _, m in ipairs(Config.models) do hashes[#hashes + 1] = joaat(m) end

local function nearestDumpster(coords)
    for _, h in ipairs(hashes) do
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z,
            Config.distance + 0.5, h, false, false, false)
        if obj ~= 0 then return obj end
    end
end

CreateThread(function()
    local showing = false
    while true do
        local wait = 750
        if not Client.open then
            local coords = GetEntityCoords(cache.ped)
            local obj = nearestDumpster(coords)

            if obj and #(coords - GetEntityCoords(obj)) <= Config.distance then
                wait = 0
                if not showing then
                    lib.showTextUI(Locale.t('hint_search'), { position = 'left-center' })
                    showing = true
                end
                if IsControlJustReleased(0, Config.key) then
                    lib.hideTextUI(); showing = false
                    local id = lib.callback.await('lk_inv:searchDumpster', false, GetEntityCoords(obj))
                    if id then Client.openInventory(id) end
                end
            elseif showing then
                lib.hideTextUI(); showing = false
            end
        elseif showing then
            lib.hideTextUI(); showing = false
        end
        Wait(wait)
    end
end)
