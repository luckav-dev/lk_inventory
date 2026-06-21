local Items  = require 'config.items'
local Locale = require 'shared.locale'
local Client = require 'client.main'

--- Carry heavy items in your hands: a looped animation, the prop attached to
--- your hand, slowed movement and no sprint/weapons. Press E to set it down,
--- which turns it into a real ground object.
local Carry = {}

local active -- { slot, name, prop, dict }

local function attachProp(model, cfg)
    local hash = joaat(model)
    RequestModel(hash)
    local deadline = GetGameTimer() + 1000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    local c = GetEntityCoords(cache.ped)
    local obj = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    local bone = GetPedBoneIndex(cache.ped, cfg.bone)
    AttachEntityToEntity(obj, cache.ped, bone, cfg.pos.x, cfg.pos.y, cfg.pos.z,
        cfg.rot.x, cfg.rot.y, cfg.rot.z, true, true, false, true, 1, true)
    return obj
end

function Carry.start(item)
    if active or not item then return end
    local def = Items[item.name]
    local cfg = def and def.carry
    if not cfg then return end

    lib.requestAnimDict(cfg.dict)
    TaskPlayAnim(cache.ped, cfg.dict, cfg.anim, 4.0, -4.0, -1, 49, 0, false, false, false)

    active = {
        slot = item.slot, name = item.name,
        prop = attachProp(cfg.prop, cfg), dict = cfg.dict,
    }

    if lib.showTextUI then lib.showTextUI(Locale.t('hint_setdown'), { position = 'left-center' }) end

    -- Lock movement/weapons and drop on E.
    CreateThread(function()
        while active do
            DisableControlAction(0, 21, true)  -- sprint
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            SetPedMoveRateOverride(cache.ped, 0.75)
            if IsControlJustReleased(0, 38) then -- E
                Carry.stop(true)
            end
            Wait(0)
        end
    end)
end

--- Stop carrying. When `putDown`, the item is dropped as a ground object.
function Carry.stop(putDown)
    if not active then return end
    local cur = active
    active = nil

    if cur.prop and DoesEntityExist(cur.prop) then DeleteEntity(cur.prop) end
    ClearPedTasks(cache.ped)
    RemoveAnimDict(cur.dict)
    if lib.hideTextUI then lib.hideTextUI() end

    if putDown then
        local c = GetEntityCoords(cache.ped)
        local fwd = GetEntityForwardVector(cache.ped)
        local dropPos = vec3(c.x + fwd.x * 0.8, c.y + fwd.y * 0.8, c.z)
        lib.callback.await('lk_inv:swap', false, {
            fromSlot = cur.slot, fromType = 'player',
            toSlot = 1, toType = 'newdrop', count = 1,
            coords = dropPos,
        })
    end
end

_G.LkCarry = Carry

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and active then Carry.stop(false) end
end)

return Carry
