local Config = require 'config.config'
local Items  = require 'config.items'

--- Throw an item by hand: the item shows in your hand, you play a throwing
--- animation (grenade/snowball style), then it's released as a flying physics
--- object. Where it lands, the server spawns the real ground drop.
local Throw = {}

local active = false
local inFlight -- the prop currently attached/airborne (for cleanup on stop)

-- Default hand placement; items can override via `hold = { pos, rot }`.
local DEFAULT_HOLD = { pos = vec3(0.12, 0.02, 0.0), rot = vec3(0.0, 0.0, 0.0) }

local function makeProp(render)
    if render.weapon then
        local hash = joaat(render.weapon)
        RequestWeaponAsset(hash, 31, 0)
        local deadline = GetGameTimer() + 1000
        while not HasWeaponAssetLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
        return CreateWeaponObject(hash, 1, 0.0, 0.0, 0.0, true, 1.0, 0)
    end

    local hash = joaat(render.model or Config.drops.fallbackModel)
    RequestModel(hash)
    local deadline = GetGameTimer() + 1000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    local obj = CreateObject(hash, 0.0, 0.0, 0.0, true, true, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

function Throw.start(data)
    if active or not Config.throw.enabled or not data or not data.render then return end
    active = true

    local cfg = Config.throw
    local ped = cache.ped

    -- Item visible in the right hand, using its per-item hold offset.
    local obj = makeProp(data.render)
    if not obj or obj == 0 then active = false; return end
    inFlight = obj
    local hold = (Items[data.name] and Items[data.name].hold) or DEFAULT_HOLD
    local bone = GetPedBoneIndex(ped, 28422) -- PH_R_Hand
    AttachEntityToEntity(obj, ped, bone,
        hold.pos.x, hold.pos.y, hold.pos.z,
        hold.rot.x, hold.rot.y, hold.rot.z,
        true, true, false, true, 1, true)

    -- Throwing animation (tunable in config).
    lib.requestAnimDict(cfg.anim.dict)
    TaskPlayAnim(ped, cfg.anim.dict, cfg.anim.clip, 4.0, -4.0, -1, 48, 0, false, false, false)

    Wait(cfg.anim.release)

    -- Release: detach and launch it along the camera aim direction.
    DetachEntity(obj, true, true)
    SetEntityCollision(obj, true, true)
    ActivatePhysics(obj)

    local cam = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(cam.x), math.rad(cam.z)
    local fx = -math.sin(yaw) * math.cos(pitch)
    local fy = math.cos(yaw) * math.cos(pitch)
    local fz = math.sin(pitch)
    SetEntityVelocity(obj, fx * cfg.force, fy * cfg.force, fz * cfg.force + cfg.upForce)
    if _G.LkSound then LkSound.play('throw') end

    ClearPedTasks(ped)
    RemoveAnimDict(cfg.anim.dict)

    -- Let it land, report the resting position, and remove the temp prop (the
    -- server then spawns the persistent drop everyone sees).
    Wait(cfg.settle)
    local coords = GetEntityCoords(obj)
    if DoesEntityExist(obj) then DeleteEntity(obj) end
    inFlight = nil
    TriggerServerEvent('lk_inv:throwLand', coords)

    active = false
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and inFlight and DoesEntityExist(inFlight) then
        DeleteEntity(inFlight)
        ClearPedTasks(cache.ped)
    end
end)

return Throw
