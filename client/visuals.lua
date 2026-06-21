local Config = require 'config.config'

--- Visible body equipment ox_inventory doesn't render: holstered weapons appear
--- on the body (rifles on the back, pistols on the thigh) and a backpack is worn
--- when you carry a bag. The equipped weapon is hidden (it's in your hands).

if not Config.visuals.enabled then return end

local Items = require 'config.items'
local V = Config.visuals

local Visuals = {}
local attachedWeapons = {} -- name -> object
local attachedBag
local equippedName
local equipment = { weapons = {}, bag = false }

local function slotFor(name)
    local def = Items[name]
    local key = (def and def.bodySlot) or 'back'
    return V.slots[key] or V.slots.back
end

local function attachAt(obj, slotCfg)
    local bone = GetPedBoneIndex(cache.ped, slotCfg.bone)
    AttachEntityToEntity(obj, cache.ped, bone,
        slotCfg.pos.x, slotCfg.pos.y, slotCfg.pos.z,
        slotCfg.rot.x, slotCfg.rot.y, slotCfg.rot.z,
        true, true, false, true, 1, true)
end

local function makeProp(model, slotCfg)
    local hash = type(model) == 'string' and joaat(model) or model
    RequestModel(hash)
    local deadline = GetGameTimer() + 1000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    local c = GetEntityCoords(cache.ped)
    local obj = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    attachAt(obj, slotCfg)
    return obj
end

local function makeWeapon(name, slotCfg)
    local hash = joaat(name)
    RequestWeaponAsset(hash, 31, 0)
    local deadline = GetGameTimer() + 1000
    while not HasWeaponAssetLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    local c = GetEntityCoords(cache.ped)
    local obj = CreateWeaponObject(hash, 0, c.x, c.y, c.z, true, 1.0, 0)
    attachAt(obj, slotCfg)
    return obj
end

local function render()
    -- Weapons: everything owned except the one currently in hand.
    local desired = {}
    for _, w in ipairs(equipment.weapons or {}) do
        if w.name ~= equippedName then desired[w.name] = true end
    end

    for name, obj in pairs(attachedWeapons) do
        if not desired[name] then
            if DoesEntityExist(obj) then DeleteEntity(obj) end
            attachedWeapons[name] = nil
        end
    end
    for name in pairs(desired) do
        if not attachedWeapons[name] then
            attachedWeapons[name] = makeWeapon(name, slotFor(name))
        end
    end

    -- Backpack
    if equipment.bag and not attachedBag then
        attachedBag = makeProp(V.bag.prop, V.bag)
    elseif not equipment.bag and attachedBag then
        if DoesEntityExist(attachedBag) then DeleteEntity(attachedBag) end
        attachedBag = nil
    end
end

local function clearAll()
    for _, obj in pairs(attachedWeapons) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    attachedWeapons = {}
    if attachedBag and DoesEntityExist(attachedBag) then DeleteEntity(attachedBag) end
    attachedBag = nil
end

RegisterNetEvent('lk_inv:visuals', function(set)
    equipment = set or { weapons = {}, bag = false }
    render()
end)

--- Called by the weapons module when a weapon is drawn/holstered.
function Visuals.setEquipped(name)
    equippedName = name
    render()
end

_G.LkVisuals = Visuals

-- Reattach after a ped change (respawn / model swap).
CreateThread(function()
    local lastPed = cache.ped
    while true do
        if cache.ped ~= lastPed then
            lastPed = cache.ped
            clearAll()
            render()
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearAll() end
end)
