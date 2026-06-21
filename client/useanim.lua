local Items = require 'config.items'

--- Plays an item's use animation (drink, eat, bandage...) with the item shown
--- in the hand. Driven by the item's `useAnim = { dict, clip, duration, prop?,
--- noProp? }`; the prop defaults to the item's `ground` model and uses its
--- `hold` offset.
local UseAnim = {}

local DEFAULT_HOLD = { pos = vec3(0.12, 0.02, 0.0), rot = vec3(0.0, 0.0, 0.0) }
local busy = false
local currentProp -- prop attached during a use animation (for cleanup on stop)

local function attachProp(model, hold)
    local hash = joaat(model)
    RequestModel(hash)
    local deadline = GetGameTimer() + 1000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end

    local c = GetEntityCoords(cache.ped)
    local obj = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    local bone = GetPedBoneIndex(cache.ped, 28422) -- PH_R_Hand
    AttachEntityToEntity(obj, cache.ped, bone,
        hold.pos.x, hold.pos.y, hold.pos.z,
        hold.rot.x, hold.rot.y, hold.rot.z,
        true, true, false, true, 1, true)
    return obj
end

--- @param name string item name
function UseAnim.play(name)
    if busy then return end
    local def = Items[name]
    local anim = def and def.useAnim
    if not anim then return end

    busy = true

    local ped = cache.ped
    if not anim.noProp then
        local model = anim.prop or def.ground
        if model then currentProp = attachProp(model, def.hold or DEFAULT_HOLD) end
    end

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, -4.0, anim.duration or 3000, 49, 0, false, false, false)
    if _G.LkSound then LkSound.play('use') end

    Wait(anim.duration or 3000)

    ClearPedTasks(ped)
    RemoveAnimDict(anim.dict)
    if currentProp and DoesEntityExist(currentProp) then DeleteEntity(currentProp) end
    currentProp = nil

    busy = false
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and currentProp and DoesEntityExist(currentProp) then
        DeleteEntity(currentProp)
        ClearPedTasks(cache.ped)
    end
end)

return UseAnim
