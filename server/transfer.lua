local Inventory = require 'server.inventory'
local Utils     = require 'shared.utils'

--- Server-authoritative slot transfer between two inventories.
--- Handles move into empty, stack onto same item, split, and swap.
local Transfer = {}

local function sameItem(a, b)
    return a.name == b.name
        and json.encode(a.metadata or {}) == json.encode(b.metadata or {})
end

--- @param from Inventory
--- @param fromSlotId integer
--- @param to Inventory
--- @param toSlotId integer
--- @param count integer
--- @return boolean success
function Transfer.move(from, fromSlotId, to, toSlotId, count)
    local fromSlot = from.items[fromSlotId]
    if not fromSlot then return false end

    count = math.floor(count or fromSlot.count)
    if count < 1 then return false end
    if count > fromSlot.count then count = fromSlot.count end

    local def = Inventory.itemDef(fromSlot.name)
    if not def then return false end

    -- Non-stackable items can't be split (would create two slots sharing one
    -- unique instance / metadata).
    if not def.stack and count ~= fromSlot.count then return false end

    -- Containers can't be nested inside another container (and never inside
    -- themselves) — this prevents weight-propagation cycles / infinite recursion.
    if fromSlot.metadata and fromSlot.metadata.container then
        if to.type == 'container' or fromSlot.metadata.container == to.id then
            return false
        end
    end

    local moveWeight = Inventory.slotWeight(fromSlot.name, count)
    local toSlot = to.items[toSlotId]

    -- Stack onto a matching slot
    if toSlot and sameItem(toSlot, fromSlot) and def.stack then
        if not to:canHold(moveWeight) and from ~= to then return false end
        toSlot.count = toSlot.count + count
        toSlot.weight = Inventory.slotWeight(toSlot.name, toSlot.count)
        from:removeFromSlot(fromSlotId, count)
        to:recalcWeight(); to.dirty = true
        return true
    end

    -- Swap two different occupied slots (only whole-slot swaps)
    if toSlot and not sameItem(toSlot, fromSlot) then
        if count ~= fromSlot.count then return false end
        if from == to then
            from.items[fromSlotId], from.items[toSlotId] = toSlot, fromSlot
            fromSlot.slot, toSlot.slot = toSlotId, fromSlotId
        else
            -- weight feasibility on both sides after the exchange
            local fromAfter = from.weight - fromSlot.weight + toSlot.weight
            local toAfter   = to.weight - toSlot.weight + fromSlot.weight
            if fromAfter > from.maxWeight or toAfter > to.maxWeight then return false end

            fromSlot.slot, toSlot.slot = toSlotId, fromSlotId
            from.items[fromSlotId] = toSlot
            to.items[toSlotId] = fromSlot
            from:recalcWeight(); to:recalcWeight()
        end
        from.dirty, to.dirty = true, true
        return true
    end

    -- Move into an empty slot (full or partial)
    if not toSlot then
        if from ~= to and not to:canHold(moveWeight) then return false end

        -- On a partial move the source slot survives, so the destination needs
        -- its own metadata table (never share one instance across two slots).
        local partial = count < fromSlot.count
        to.items[toSlotId] = {
            slot = toSlotId,
            name = fromSlot.name,
            count = count,
            weight = moveWeight,
            metadata = partial and Utils.clone(fromSlot.metadata) or fromSlot.metadata,
        }
        from:removeFromSlot(fromSlotId, count)
        to:recalcWeight(); to.dirty = true
        return true
    end

    return false
end

return Transfer
