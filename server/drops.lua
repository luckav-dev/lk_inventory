local Config    = require 'config.config'
local Inventory = require 'server.inventory'
local Utils     = require 'shared.utils'

--- Ground drops. Each drop is a real inventory (so items can be taken/added)
--- plus world metadata (coords + the model to render). Clients spawn the
--- actual object for realism.
local Drops = {}

--- id -> { coords, model, weapon, owner }
local meta = {}
local seq = 0
local totalCount = 0
local perOwner = {} -- owner -> active drop count

local function newId()
    seq = seq + 1
    return ('drop_%d_%d'):format(seq, math.random(1000, 9999))
end

--- Anti-dump: is this owner allowed to create another ground drop right now?
function Drops.canCreate(owner)
    if totalCount >= Config.drops.maxTotal then return false end
    if owner and (perOwner[owner] or 0) >= Config.drops.maxPerPlayer then return false end
    return true
end

--- Resolve the world model for a dropped item. Weapons render as the weapon
--- itself; other items use their configured `ground` model or the fallback.
local function resolveModel(name)
    local def = Inventory.itemDef(name)
    if def and def.weapon then
        return { weapon = name }
    end
    return { model = (def and def.ground) or Config.drops.fallbackModel }
end

--- Create a ground drop holding one slot of an item.
--- @return string|nil dropId
function Drops.create(coords, name, count, metadata, owner)
    if not coords or not name then return nil end
    if not Drops.canCreate(owner) then return nil end

    local id = newId()
    local inv = Inventory.create(id, {
        type = 'drop',
        label = 'Ground',
        slots = 10,
        maxWeight = Config.drops.maxWeight,
        items = {},
    })

    inv:addItem(name, count, metadata)

    local render = resolveModel(name)
    meta[id] = {
        coords = coords,
        model  = render.model,
        weapon = render.weapon,
        owner  = owner,
    }
    totalCount = totalCount + 1
    if owner then perOwner[owner] = (perOwner[owner] or 0) + 1 end

    TriggerClientEvent('lk_inv:spawnDrop', -1, id, coords, render)
    Utils.log('debug', 'drop created', id, name, count)
    return id
end

--- Remove a drop entirely (e.g. once emptied).
function Drops.remove(id)
    local m = meta[id]
    if not m then return end
    if m.owner and perOwner[m.owner] then
        perOwner[m.owner] = math.max(0, perOwner[m.owner] - 1)
    end
    totalCount = math.max(0, totalCount - 1)
    meta[id] = nil
    Inventory.remove(id)
    TriggerClientEvent('lk_inv:removeDrop', -1, id)
end

--- Send all active drops to a client (on join / resource restart).
function Drops.syncTo(source)
    for id, m in pairs(meta) do
        TriggerClientEvent('lk_inv:spawnDrop', source, id, m.coords,
            { model = m.model, weapon = m.weapon })
    end
end

function Drops.exists(id)
    return meta[id] ~= nil
end

function Drops.getCoords(id)
    return meta[id] and meta[id].coords
end

--- Relocate a drop (e.g. after a kick) and re-broadcast it to all clients so
--- the world object and its pickup point follow.
function Drops.move(id, coords)
    local m = meta[id]
    if not m or not coords then return end
    m.coords = coords
    TriggerClientEvent('lk_inv:removeDrop', -1, id)
    TriggerClientEvent('lk_inv:spawnDrop', -1, id, coords, { model = m.model, weapon = m.weapon })
end

return Drops
