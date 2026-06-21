local Items  = require 'config.items'
local Locale = require 'shared.locale'
local Notify = require 'client.notify'

--- Weapon handling: equip/holster via use, ammo + durability persistence, and
--- attachment apply/remove. Durability decreases per bullet fired.
local Weapons = {}

local DURABILITY_PER_BULLET = 0.5
local current -- { slot, name, hash, durability, components = { names } }

local function applyComponents(hash, names)
    for _, cname in ipairs(names or {}) do
        local def = Items[cname]
        local comps = def and def.client and def.client.component
        for _, ch in ipairs(comps or {}) do
            GiveWeaponComponentToPed(cache.ped, hash, joaat(ch))
        end
    end
end

function Weapons.equip(slot, name, metadata)
    local ped = cache.ped
    local hash = joaat(name)
    metadata = metadata or {}

    RequestWeaponAsset(hash, 31, 0)
    local deadline = GetGameTimer() + 1000
    while not HasWeaponAssetLoaded(hash) and GetGameTimer() < deadline do Wait(0) end

    GiveWeaponToPed(ped, hash, metadata.ammo or 0, false, true)
    SetCurrentPedWeapon(ped, hash, true)
    SetPedAmmo(ped, hash, metadata.ammo or 0)
    applyComponents(hash, metadata.components)

    current = {
        slot = slot, name = name, hash = hash,
        durability = metadata.durability or 100,
        components = metadata.components or {},
    }

    -- Hide this weapon's body prop (it's now in hand).
    if _G.LkVisuals then LkVisuals.setEquipped(name) end
end

function Weapons.holster(syncBack)
    if not current then return end
    local ped = cache.ped

    if syncBack ~= false then
        TriggerServerEvent('lk_inv:syncWeapon', current.slot, {
            ammo = GetAmmoInPedWeapon(ped, current.hash),
            durability = current.durability,
            components = current.components,
        })
    end

    RemoveWeaponFromPed(ped, current.hash)
    current = nil

    -- The weapon returns to the body.
    if _G.LkVisuals then LkVisuals.setEquipped(nil) end
end

--- Toggle equip/holster from a "use" on a weapon item.
function Weapons.use(weapon)
    if current and current.slot == weapon.slot then
        return Weapons.holster()
    end
    if current then Weapons.holster() end
    Weapons.equip(weapon.slot, weapon.name, weapon.metadata)
end

--- Repair the equipped weapon using a repair kit.
function Weapons.repair(kit)
    if not current then
        Notify.send({ type = 'error', description = Locale.t('equip_to_repair') })
        return
    end
    local result = lib.callback.await('lk_inv:repairWeapon', false,
        { kitSlot = kit.slot, weaponSlot = current.slot })
    if result then
        current.durability = result
        Notify.send({ type = 'success', description = Locale.t('weapon_repaired') })
    end
end

--- Attach a component item to the currently equipped weapon.
function Weapons.attach(component)
    if not current then
        Notify.send({ type = 'error', description = Locale.t('equip_weapon_first') })
        return
    end

    local applied = lib.callback.await('lk_inv:attachComponent', false, {
        weaponSlot = current.slot, componentSlot = component.slot,
    })
    if applied then
        applyComponents(current.hash, { applied })
        current.components[#current.components + 1] = applied
    end
end

--- Remove a component (from the weapon modal) and return it to the inventory.
function Weapons.removeComponent(slot, componentName)
    if not slot or not componentName then return end

    local removed = lib.callback.await('lk_inv:removeComponent', false,
        { slot = slot, component = componentName })
    if not removed then return end

    if current and current.slot == slot then
        local def = Items[removed]
        for _, ch in ipairs((def and def.client and def.client.component) or {}) do
            RemoveWeaponComponentFromPed(cache.ped, current.hash, joaat(ch))
        end
        for i = #current.components, 1, -1 do
            if current.components[i] == removed then table.remove(current.components, i); break end
        end
    end
end

-- Durability: tie wear to bullets actually fired.
CreateThread(function()
    local lastAmmo
    while true do
        if current then
            local ammo = GetAmmoInPedWeapon(cache.ped, current.hash)
            if lastAmmo and ammo < lastAmmo then
                current.durability = math.max(0, current.durability - (lastAmmo - ammo) * DURABILITY_PER_BULLET)
                if current.durability <= 0 then
                    Notify.send({ type = 'error', description = Locale.t('weapon_broken') })
                    SetPedAmmo(cache.ped, current.hash, 0)
                end
            end
            lastAmmo = ammo
            Wait(200)
        else
            lastAmmo = nil
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and current then Weapons.holster(false) end
end)

return Weapons
