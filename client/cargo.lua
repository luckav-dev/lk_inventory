local Config = require 'config.config'

--- Surprising realism ox_inventory doesn't do: the weight of what's in the
--- trunk affects how the vehicle drives. A loaded van/truck accelerates noticeably
--- slower than an empty one. The torque multiplier is refreshed when you enter a
--- vehicle and periodically while driving (the trunk contents can change).

if not Config.cargo.enabled then return end

local currentVeh, loadRatio = nil, 0

local function refreshLoad(veh)
    if not veh or veh == 0 then loadRatio = 0; return end
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then loadRatio = 0; return end
    loadRatio = lib.callback.await('lk_inv:trunkLoad', false, plate:gsub('%s+$', '')) or 0
end

CreateThread(function()
    while true do
        local veh = cache.vehicle
        if veh and GetPedInVehicleSeat(veh, -1) == cache.ped then
            if veh ~= currentVeh then
                currentVeh = veh
                refreshLoad(veh)
            end

            if loadRatio > 0 then
                -- 1.0 (empty) → 1.0 - maxPenalty (full)
                local mult = 1.0 - loadRatio * Config.cargo.maxPenalty
                SetVehicleEngineTorqueMultiplier(veh, mult)
            end
            Wait(250)
        else
            currentVeh = nil
            loadRatio = 0
            Wait(750)
        end
    end
end)

-- Re-query the load every few seconds in case the trunk contents changed.
CreateThread(function()
    while true do
        Wait(6000)
        if currentVeh and currentVeh == cache.vehicle then
            refreshLoad(currentVeh)
        end
    end
end)
