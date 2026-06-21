local Config = require 'config.config'
local Items  = require 'config.items'
local Utils  = require 'shared.utils'

--- Core inventory model. An Inventory is a container of numbered slots; the
--- server is always the authority. Player inventories are keyed by source,
--- other containers (drops, stashes) by their string id.
---@class Inventory
---@field id string|number
---@field type string
---@field owner string|nil   persistence key (citizenid, stash id, ...)
---@field label string
---@field slots integer
---@field maxWeight integer
---@field weight integer
---@field items table<integer, table>
---@field dirty boolean
local Inventory = {}
Inventory.__index = Inventory

--- Live inventories indexed by id.
local store = {}

--- Monotonic unique id for container instances.
local uidSeq = 0
local function uid(prefix)
    uidSeq = uidSeq + 1
    return ('%s_%d_%d'):format(prefix or 'id', uidSeq, math.random(10000, 99999))
end

--- @param name string
--- @return table|nil item definition
local function itemDef(name)
    if not name then return nil end
    return Items[name]
end
Inventory.itemDef = itemDef

--- Weight of a single slot (definition weight * count).
local function slotWeight(name, count)
    local def = itemDef(name)
    if not def then return 0 end
    return (def.weight or 0) * (count or 1)
end
Inventory.slotWeight = slotWeight

--- Build a fresh, validated slot list from raw stored data, dropping any
--- entries that reference unknown items.
local function sanitize(rawItems)
    local items, total = {}, 0

    for _, slot in pairs(rawItems or {}) do
        if type(slot) == 'table' and slot.name and slot.slot then
            local def = itemDef(slot.name)
            if def then
                local count = Utils.posInt(slot.count)
                if count > 0 then
                    local weight = slotWeight(slot.name, count)
                    items[slot.slot] = {
                        slot = slot.slot,
                        name = slot.name,
                        count = count,
                        weight = weight,
                        metadata = slot.metadata or {},
                    }
                    total = total + weight
                end
            end
        end
    end

    return items, total
end

--- Create (or replace) an inventory and register it in the store.
function Inventory.create(id, opts)
    opts = opts or {}
    local items, weight = sanitize(opts.items)

    local inv = setmetatable({
        id        = id,
        type      = opts.type or 'player',
        owner     = opts.owner,
        label     = opts.label or tostring(id),
        slots     = opts.slots or Config.playerSlots,
        maxWeight = opts.maxWeight or Config.playerWeight,
        weight    = weight,
        items     = items,
        persist   = opts.persist == true,
        viewers   = {},
        dirty     = false,
    }, Inventory)

    store[id] = inv
    return inv
end

--- @return Inventory|nil
function Inventory.get(id)
    return store[id]
end

function Inventory.remove(id)
    store[id] = nil
end

function Inventory.all()
    return store
end

--- First free slot number, or nil when full.
function Inventory:firstFree()
    for i = 1, self.slots do
        if not self.items[i] then return i end
    end
    return nil
end

--- Find a stackable slot for an item with matching metadata.
function Inventory:findStack(name, metadata)
    local def = itemDef(name)
    if not def or not def.stack then return nil end

    for i = 1, self.slots do
        local slot = self.items[i]
        if slot and slot.name == name
            and json.encode(slot.metadata or {}) == json.encode(metadata or {}) then
            return i
        end
    end
    return nil
end

--- Effective weight of a slot, including the contents of a container item.
function Inventory:effectiveWeight(slot)
    local w = slot.weight or 0
    if slot.metadata and slot.metadata.container then
        local c = store[slot.metadata.container]
        if c then w = slotWeight(slot.name, slot.count) + c.weight end
    end
    return w
end

--- Recompute total weight from scratch (container-aware).
function Inventory:recalcWeight()
    local total = 0
    for _, slot in pairs(self.items) do
        total = total + self:effectiveWeight(slot)
    end
    self.weight = total
    return total
end

--- @return boolean ok whether `extra` grams still fit
function Inventory:canHold(extra)
    return (self.weight + (extra or 0)) <= self.maxWeight
end

--- Add an item, honouring stacking and weight limits.
--- @return boolean success
function Inventory:addItem(name, count, metadata)
    local def = itemDef(name)
    if not def then return false end

    count = Utils.posInt(count)
    if count == 0 then count = 1 end

    -- Initialise metadata for special item types.
    metadata = metadata or {}
    if def.weapon then
        if metadata.durability == nil then metadata.durability = 100 end
        if metadata.ammo == nil then metadata.ammo = 0 end
    elseif def.container and not metadata.container then
        metadata.container = uid('cont')
    end

    -- Perishable items: store an expiry timestamp the UI counts down from.
    if def.degrade and metadata.durability == nil then
        metadata.durability = os.time() + def.degrade * 60
    end

    -- Limited-use items (lighter, spray, kit) track remaining charges.
    if def.uses and metadata.uses == nil then
        metadata.uses = def.uses
    end

    -- Unique instance id for non-stackable items, used by duplication detection
    -- (a single instance must never appear in two inventories at once).
    if not def.stack and not metadata.__uid and not metadata.serial and not metadata.container then
        metadata.__uid = uid('item')
    end

    local addWeight = slotWeight(name, count)
    if not self:canHold(addWeight) then return false end

    local target = self:findStack(name, metadata) or self:firstFree()
    if not target then return false end

    local existing = self.items[target]
    if existing then
        existing.count = existing.count + count
        existing.weight = slotWeight(name, existing.count)
    else
        self.items[target] = {
            slot = target,
            name = name,
            count = count,
            weight = addWeight,
            metadata = metadata or {},
        }
    end

    self:recalcWeight()
    self.dirty = true
    return true
end

--- Remove `count` from a specific slot (or the item by name across slots).
--- @return boolean success
function Inventory:removeFromSlot(slotId, count)
    local slot = self.items[slotId]
    if not slot then return false end

    count = Utils.posInt(count)
    if count == 0 or count >= slot.count then
        self.items[slotId] = nil
    else
        slot.count = slot.count - count
        slot.weight = slotWeight(slot.name, slot.count)
    end

    self:recalcWeight()
    self.dirty = true
    return true
end

--- The inventory key the NUI uses to route refresh payloads ('player' for the
--- viewer's own inventory, otherwise the container id).
function Inventory:clientKey()
    return self.type == 'player' and 'player' or self.id
end

--- Refresh payload for a single slot (empty slots send just the slot number).
function Inventory:slotPayload(slotId)
    local slot = self.items[slotId]
    if slot and slot.metadata and slot.metadata.container and store[slot.metadata.container] then
        local copy = {}
        for k, v in pairs(slot) do copy[k] = v end
        copy.weight = self:effectiveWeight(slot)
        return { item = copy, inventory = self:clientKey() }
    end
    return { item = slot or { slot = slotId }, inventory = self:clientKey() }
end

function Inventory:addViewer(source)
    self.viewers[source] = true
end

function Inventory:removeViewer(source)
    self.viewers[source] = nil
end

--- Serialise to the shape the NUI expects. Container slots report their full
--- weight (base + contents) for display.
function Inventory:toClient()
    local items = {}
    for _, slot in pairs(self.items) do
        if slot.metadata and slot.metadata.container and store[slot.metadata.container] then
            local copy = {}
            for k, v in pairs(slot) do copy[k] = v end
            copy.weight = self:effectiveWeight(slot)
            items[#items + 1] = copy
        else
            items[#items + 1] = slot
        end
    end

    return {
        id        = self.id,
        type      = self.type,
        label     = self.label,
        slots     = self.slots,
        maxWeight = self.maxWeight,
        weight    = self.weight,
        items     = items,
    }
end

return Inventory
