local Client = require 'client.main'

--- Frisk the nearest player (allowed server-side only when they're down or
--- flagged searchable) and a hands-up toggle that makes you frisk-able.

local function nearestPlayer()
    local me = cache.ped
    local coords = GetEntityCoords(me)
    local target, best
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= me and DoesEntityExist(ped) then
            local d = #(coords - GetEntityCoords(ped))
            if d < 2.2 and (not best or d < best) then
                best, target = d, GetPlayerServerId(pid)
            end
        end
    end
    return target
end

RegisterCommand('search', function()
    if Client.open then return end
    local target = nearestPlayer()
    if not target then return end
    local id = lib.callback.await('lk_inv:searchPlayer', false, target)
    if id then Client.openInventory(id) end
end, false)

-- Stealth: try to pickpocket one item from the nearest player.
RegisterCommand('pickpocket', function()
    if Client.open then return end
    local target = nearestPlayer()
    if target then lib.callback.await('lk_inv:pickpocket', false, target) end
end, false)

-- Hidden world stashes: bury one at your feet, or search the ground for one.
RegisterCommand('hidestash', function()
    if Client.open then return end
    local id = lib.callback.await('lk_inv:hideStash', false, GetEntityCoords(cache.ped))
    if id then Client.openInventory(id) end
end, false)

RegisterCommand('searchground', function()
    if Client.open then return end
    local id = lib.callback.await('lk_inv:searchGround', false, GetEntityCoords(cache.ped))
    if id then Client.openInventory(id) end
end, false)

local handsUp = false
RegisterCommand('handsup', function()
    handsUp = not handsUp
    if handsUp then
        lib.requestAnimDict('missminuteman_1ig_2')
        TaskPlayAnim(cache.ped, 'missminuteman_1ig_2', 'handsup_base', 4.0, -4.0, -1, 49, 0, false, false, false)
        TriggerServerEvent('lk_inv:setSearchable', true)
    else
        ClearPedTasks(cache.ped)
        TriggerServerEvent('lk_inv:setSearchable', false)
    end
end, false)
RegisterKeyMapping('handsup', 'Hands up / surrender', 'keyboard', 'X')
