local Config    = require 'config.config'
local Db        = require 'server.db'
local Inventory = require 'server.inventory'

--- Periodic inventory snapshots for anti-dupe rollback. Kept in memory per
--- player (loaded from the database on join) and persisted so they survive a
--- restart. An admin can list and restore them.
local Snapshots = {}

local buffers = {} -- source -> { { at, items } } newest-first

local function serialize(inv)
    local list = {}
    for _, slot in pairs(inv.items) do list[#list + 1] = slot end
    return list
end

--- Capture the player's current inventory.
function Snapshots.take(source)
    if not Config.snapshots.enabled then return end
    local inv = Inventory.get(source)
    if not inv or inv.type ~= 'player' then return end

    local items = serialize(inv)
    buffers[source] = buffers[source] or {}
    table.insert(buffers[source], 1, { at = os.time(), items = items })
    while #buffers[source] > Config.snapshots.keep do
        table.remove(buffers[source])
    end

    if inv.owner then
        Db.saveSnapshot(inv.owner, json.encode(items), Config.snapshots.keep)
    end
end

--- Load a player's stored snapshots into memory (call on join).
function Snapshots.loadFor(source, ownerId)
    local rows = Db.loadSnapshots(ownerId, Config.snapshots.keep)
    local buf = {}
    for i = 1, #rows do
        local ok, items = pcall(json.decode, rows[i].slots_json)
        buf[i] = { at = rows[i].taken_at, items = (ok and type(items) == 'table') and items or {} }
    end
    buffers[source] = buf
end

--- Summaries for the admin UI/console.
function Snapshots.list(source)
    local buf = buffers[source] or {}
    local out = {}
    for i = 1, #buf do
        out[i] = { index = i, at = buf[i].at, slots = #buf[i].items }
    end
    return out
end

--- Restore the inventory to snapshot `index`, in place (keeps viewers/refs).
--- @return boolean ok
function Snapshots.restore(source, index)
    local buf = buffers[source]
    local snap = buf and buf[index]
    local inv = Inventory.get(source)
    if not snap or not inv then return false end

    local items, total = {}, 0
    for _, s in pairs(snap.items) do
        if type(s) == 'table' and s.name and s.slot then
            local def = Inventory.itemDef(s.name)
            local count = tonumber(s.count) or 0
            if def and count > 0 then
                local weight = Inventory.slotWeight(s.name, count)
                items[s.slot] = {
                    slot = s.slot, name = s.name, count = count,
                    weight = weight, metadata = s.metadata or {},
                }
                total = total + weight
            end
        end
    end

    inv.items = items
    inv.weight = total
    inv:recalcWeight()
    inv.dirty = true
    return true
end

function Snapshots.clear(source)
    buffers[source] = nil
end

return Snapshots
