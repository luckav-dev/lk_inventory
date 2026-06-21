local Config = require 'config.config'
local Locale = require 'shared.locale'
local Client = require 'client.main'
local Notify = require 'client.notify'

--- Find the closest vehicle to a position within `maxDist`.
local function closestVehicle(coords, maxDist)
    local best, bestDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(coords - GetEntityCoords(veh))
        if dist <= maxDist and (not bestDist or dist < bestDist) then
            best, bestDist = veh, dist
        end
    end
    return best
end

--- Open glovebox when seated, otherwise the nearest vehicle's trunk on foot.
local function openVehicleStorage()
    if Client.open or not Client.uiLoaded then return end

    local ped = cache.ped
    local veh, vtype

    if cache.vehicle then
        veh, vtype = cache.vehicle, 'glovebox'
    else
        veh = closestVehicle(GetEntityCoords(ped), Config.vehicles.trunkDist)
        vtype = 'trunk'
        -- Trunk requires the vehicle to be unlocked.
        if veh and GetVehicleDoorLockStatus(veh) == 2 then
            return Notify.send({ type = 'error', description = Locale.t('vehicle_locked') })
        end
    end

    if not veh or veh == 0 then return end

    if not NetworkGetEntityIsNetworked(veh) then return end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))

    local containerId = lib.callback.await('lk_inv:prepVehicle', false, {
        netId = netId,
        vtype = vtype,
        class = GetVehicleClass(veh),
        model = model and model:lower() or nil,
    })
    if containerId then Client.openInventory(containerId) end
end

RegisterCommand('lk_inv_vehicle', openVehicleStorage, false)

if Config.vehicles.key and Config.vehicles.key ~= '' then
    RegisterKeyMapping('lk_inv_vehicle', 'Open vehicle storage (trunk/glovebox)',
        'keyboard', Config.vehicles.key)
end
