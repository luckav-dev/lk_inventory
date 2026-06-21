local ShopDefs  = require 'config.shops'
local Inventory = require 'server.inventory'
local Utils     = require 'shared.utils'

--- Read-only shop containers. Stock is unlimited; each slot carries a `price`
--- the NUI renders as a tag. Buying is validated in server/main.lua.
local Shops = {}

local defs = {}

local function register(def)
    if type(def) ~= 'table' or not def.id then return false end
    defs[def.id] = def
    return true
end
Shops.register = register

function Shops.isShop(id)
    return defs[id] ~= nil
end

--- Build the live shop inventory on first open.
--- @return Inventory|nil
function Shops.ensure(id)
    local existing = Inventory.get(id)
    if existing then return existing end

    local def = defs[id]
    if not def then return nil end

    local list = def.inventory or {}
    local inv = Inventory.create(id, {
        type = 'shop',
        label = def.label or id,
        slots = math.max(#list, 1),
        maxWeight = 0, -- not weight-limited
        items = {},
    })

    -- Populate directly so each slot keeps its price tag.
    for i = 1, #list do
        local entry = list[i]
        local def2 = Inventory.itemDef(entry.name)
        if def2 then
            local count = entry.count or 1
            inv.items[i] = {
                slot = i,
                name = entry.name,
                count = count,
                weight = Inventory.slotWeight(entry.name, count),
                price = entry.price or 0,
                currency = entry.currency,
                metadata = {},
            }
        end
    end

    Utils.log('debug', 'shop built', id)
    return inv
end

for i = 1, #ShopDefs do register(ShopDefs[i]) end

exports('RegisterShop', function(def) return register(def) end)

return Shops
