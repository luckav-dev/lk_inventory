local Inventory = require 'server.inventory'

--- Duplication detection. Every non-stackable item instance carries a unique
--- identifier (`__uid`, or a weapon serial / container id). A given identifier
--- must exist in exactly one place at a time, so finding it in two inventories
--- means it was duplicated. This module only *detects*; the caller decides what
--- to do (log / flag / remove the copy).
local Dupe = {}

local function identifierOf(slot)
    local m = slot.metadata
    if not m then return nil end
    return m.__uid or m.serial or m.container
end

--- @return table[] duplicates  list of { invId, slotId, id, name } for each copy
--- that should be removed. When the same id is in a player and a non-player
--- inventory, the player copy is kept (deterministic regardless of scan order).
function Dupe.scan()
    local seen, dupes = {}, {}

    for invId, inv in pairs(Inventory.all()) do
        for slotId, slot in pairs(inv.items) do
            local id = identifierOf(slot)
            if id then
                local prev = seen[id]
                if not prev then
                    seen[id] = { invId = invId, slotId = slotId, type = inv.type, name = slot.name }
                elseif prev.type ~= 'player' and inv.type == 'player' then
                    -- keep this player copy, flag the earlier non-player one
                    dupes[#dupes + 1] = { invId = prev.invId, slotId = prev.slotId, id = id, name = prev.name }
                    seen[id] = { invId = invId, slotId = slotId, type = inv.type, name = slot.name }
                else
                    dupes[#dupes + 1] = { invId = invId, slotId = slotId, id = id, name = slot.name }
                end
            end
        end
    end

    return dupes
end

return Dupe
