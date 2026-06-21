local Client  = require 'client.main'
local Weapons = require 'client.weapons'
local Carry   = require 'client.carry'
local Throw   = require 'client.throw'
local UseAnim = require 'client.useanim'

--- Find the closest player's server id (used for giving items).
local function closestPlayer()
    local me = cache.ped
    local myCoords = GetEntityCoords(me)
    local closest, closestDist

    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped ~= me and DoesEntityExist(ped) then
            local dist = #(myCoords - GetEntityCoords(ped))
            if dist < 3.0 and (not closestDist or dist < closestDist) then
                closest, closestDist = GetPlayerServerId(playerId), dist
            end
        end
    end

    return closest
end

--- Every handler MUST call cb(); a missing cb() permanently stalls NUI fetches.

RegisterNUICallback('uiLoaded', function(_, cb)
    Client.uiLoaded = true
    cb(1)
end)

RegisterNUICallback('exit', function(_, cb)
    Client.closeInventory()
    cb(1)
end)

RegisterNUICallback('closeConfig', function(_, cb)
    Client.closeInventory()
    cb(1)
end)

RegisterNUICallback('swapItems', function(data, cb)
    -- Ground drop: inject the player's validated coords server-side.
    if data and data.toType == 'newdrop' then
        if cache.vehicle then return cb(false) end
        local coords = GetEntityCoords(cache.ped)
        data.coords = vec3(coords.x, coords.y, coords.z)
    end

    local ok = lib.callback.await('lk_inv:swap', false, data) or false

    -- Item sounds for moving to/from the ground.
    if ok and _G.LkSound and data then
        if data.toType == 'newdrop' then
            LkSound.play('drop')
        elseif data.fromType == 'drop' and data.toType == 'player' then
            LkSound.play('pickup')
        end
    end

    cb(ok)
end)

RegisterNUICallback('useItem', function(slot, cb)
    local result = lib.callback.await('lk_inv:useItem', false, slot)
    if type(result) == 'table' then
        if result.weapon then Weapons.use(result.weapon); return cb(true) end
        if result.component then Weapons.attach(result.component); return cb(true) end
        if result.open then Client.openInventory(result.open); return cb(true) end
        if result.carry then Carry.start(result.carry); return cb(true) end
        if result.repair then Weapons.repair(result.repair); return cb(true) end
        if result.used then UseAnim.play(result.used); return cb(true) end
    end
    cb(result or false)
end)

RegisterNUICallback('throwItem', function(data, cb)
    cb(1)
    CreateThread(function()
        local result = lib.callback.await('lk_inv:throwItem', false, data)
        if type(result) == 'table' and result.render then Throw.start(result) end
    end)
end)

RegisterNUICallback('giveItem', function(data, cb)
    local target = closestPlayer()
    if not target then return cb(false) end
    -- Lua treats 0 as truthy, so guard the count explicitly.
    local count = data and tonumber(data.count) or 1
    if count < 1 then count = 1 end
    cb(lib.callback.await('lk_inv:give', false, {
        slot = data and data.slot, count = count, target = target,
    }) or false)
end)

RegisterNUICallback('getItemData', function(name, cb)
    cb(lib.callback.await('lk_inv:getItemData', false, name))
end)

RegisterNUICallback('buyItem', function(data, cb)
    cb(lib.callback.await('lk_inv:buyItem', false, data) or false)
end)

RegisterNUICallback('craftItem', function(data, cb)
    cb(lib.callback.await('lk_inv:craftItem', false, data) or false)
end)

-- Features not yet implemented in this foundation: acknowledge cleanly so the
-- UI never stalls.
RegisterNUICallback('removeAmmo', function(_, cb) cb(false) end)
RegisterNUICallback('removeComponent', function(data, cb)
    Weapons.removeComponent(data and data.slot, data and data.component)
    cb(true)
end)
RegisterNUICallback('useButton', function(_, cb) cb(false) end)
RegisterNUICallback('lootAllComplete', function(_, cb) cb(1) end)
RegisterNUICallback('toggleClothing', function(_, cb) cb(1) end)
RegisterNUICallback('lk_inventory:checkStashPin', function(data, cb)
    cb(lib.callback.await('lk_inv:checkPin', false, data and data.stash))
end)
RegisterNUICallback('lk_inventory:unlockStashPin', function(data, cb)
    cb(lib.callback.await('lk_inv:unlockPin', false, data))
end)
