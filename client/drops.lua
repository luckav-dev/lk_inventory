local Config = require 'config.config'
local Locale = require 'shared.locale'
local Client = require 'client.main'

--- Renders ground drops as real world objects. Weapons appear as the actual
--- weapon lying on the floor; other items use their configured prop. Walking
--- close shows a prompt to open the drop.
local drops = {}

local function placeOnGround(entity, coords)
    SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z, false, false, false)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, true, true)
end

local function spawnObject(render, coords)
    if render.weapon then
        local hash = joaat(render.weapon)
        RequestWeaponAsset(hash, 31, 0)
        local deadline = GetGameTimer() + 1000
        while not HasWeaponAssetLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
        local obj = CreateWeaponObject(hash, 50, coords.x, coords.y, coords.z + 0.2, true, 1.0, 0)
        if obj and obj ~= 0 then placeOnGround(obj, coords) end
        return obj
    end

    local model = joaat(render.model or Config.drops.fallbackModel)
    lib.requestModel(model)
    local obj = CreateObject(model, coords.x, coords.y, coords.z + 0.2, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if obj and obj ~= 0 then placeOnGround(obj, coords) end
    return obj
end

--- Kick/push a ground drop: a short kick animation, then physics force in the
--- facing direction. Once it settles, the new position is reported so the drop
--- (and its pickup point) follow for everyone.
local function kickDrop(point)
    local obj = point.entity
    if not obj or not DoesEntityExist(obj) then return end
    if point.showing then lib.hideTextUI(); point.showing = false end

    -- Runs in its own thread so the shared lib.points loop is never blocked by
    -- the Waits below (otherwise all nearby points stall while a kick plays).
    CreateThread(function()
        local ped = cache.ped
        lib.requestAnimDict('melee@unarmed@streamed_core')
        TaskPlayAnim(ped, 'melee@unarmed@streamed_core', 'kick_a', 4.0, -4.0, 600, 48, 0, false, false, false)

        Wait(120)
        FreezeEntityPosition(obj, false)
        ActivatePhysics(obj)
        Wait(0) -- let physics wake before the impulse registers

        local fwd = GetEntityForwardVector(ped)
        local force = Config.drops.kickForce
        ApplyForceToEntity(obj, 1, fwd.x * force, fwd.y * force, 1.5, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        if _G.LkSound then LkSound.play('kick') end

        Wait(1200)
        ClearPedTasks(ped)
        RemoveAnimDict('melee@unarmed@streamed_core')
        if DoesEntityExist(obj) then
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            TriggerServerEvent('lk_inv:moveDrop', point.dropId, GetEntityCoords(obj))
        end
    end)
end

RegisterNetEvent('lk_inv:spawnDrop', function(id, coords, render)
    if drops[id] then return end
    if not Config.drops.spawnProps then render = { model = Config.drops.fallbackModel } end

    coords = vec3(coords.x, coords.y, coords.z)

    local point = lib.points.new({
        coords = coords,
        distance = Config.drops.renderDist,
        dropId = id,
    })

    function point:onEnter()
        if not self.entity or not DoesEntityExist(self.entity) then
            self.entity = spawnObject(render, self.coords)
        end
    end

    function point:onExit()
        if self.entity and DoesEntityExist(self.entity) then
            DeleteEntity(self.entity)
            self.entity = nil
        end
    end

    function point:nearby()
        if self.currentDistance > Config.drops.interactDist then
            if self.showing then lib.hideTextUI(); self.showing = false end
            return
        end

        if not self.showing then
            lib.showTextUI(Locale.t('hint_pickup'), { position = 'left-center' })
            self.showing = true
        end

        if Client.open then return end

        if IsControlJustReleased(0, Config.drops.pickupKey) then
            lib.hideTextUI(); self.showing = false
            Client.openInventory(id)
        elseif IsControlJustReleased(0, Config.drops.kickKey) then
            kickDrop(self)
        end
    end

    drops[id] = point
end)

RegisterNetEvent('lk_inv:removeDrop', function(id)
    local point = drops[id]
    if not point then return end
    if point.entity and DoesEntityExist(point.entity) then DeleteEntity(point.entity) end
    if point.showing then lib.hideTextUI() end
    point:remove()
    drops[id] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, point in pairs(drops) do
        if point.entity and DoesEntityExist(point.entity) then DeleteEntity(point.entity) end
    end
end)
