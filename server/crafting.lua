local BenchDefs = require 'config.crafting'
local Inventory = require 'server.inventory'
local Utils     = require 'shared.utils'

--- Crafting benches are 'crafting' containers whose slots are recipes carrying
--- `ingredients` and `duration` for the UI. Crafting itself is validated in
--- server/main.lua.
local Crafting = {}

local defs = {}

local function register(def)
    if type(def) ~= 'table' or not def.id then return false end
    defs[def.id] = def
    return true
end
Crafting.register = register

function Crafting.isBench(id)
    return defs[id] ~= nil
end

--- @return Inventory|nil
function Crafting.ensure(id)
    local existing = Inventory.get(id)
    if existing then return existing end

    local def = defs[id]
    if not def then return nil end

    local recipes = def.recipes or {}
    local inv = Inventory.create(id, {
        type = 'crafting',
        label = def.label or id,
        slots = math.max(#recipes, 1),
        maxWeight = 0,
        items = {},
    })

    for i = 1, #recipes do
        local r = recipes[i]
        local itemDef = Inventory.itemDef(r.name)
        if itemDef then
            inv.items[i] = {
                slot = i,
                name = r.name,
                count = r.count or 1,
                weight = 0,
                duration = r.duration or 3000,
                ingredients = r.ingredients or {},
                successChance = r.successChance,
                metadata = {},
            }
        end
    end

    Utils.log('debug', 'crafting bench built', id)
    return inv
end

for i = 1, #BenchDefs do register(BenchDefs[i]) end

exports('RegisterCraftingBench', function(def) return register(def) end)

return Crafting
