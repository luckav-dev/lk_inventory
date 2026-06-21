local Config    = require 'config.config'
local StashDefs = require 'config.stashes'
local Db        = require 'server.db'
local Inventory = require 'server.inventory'
local Utils     = require 'shared.utils'

--- Registry and lazy loader for persistent stash containers.
local Stashes = {}

--- id -> definition
local defs = {}

local function register(def)
    if type(def) ~= 'table' or not def.id then return false end
    defs[def.id] = {
        id = def.id,
        label = def.label or def.id,
        slots = def.slots or 50,
        weight = def.weight or 100000,
        groups = def.groups,
    }
    return true
end
Stashes.register = register

function Stashes.isStash(id)
    return defs[id] ~= nil
end

function Stashes.getDef(id)
    return defs[id]
end

--- Load the stash into memory from the database if needed, returning the live
--- inventory.
--- @return Inventory|nil
function Stashes.ensure(id)
    local existing = Inventory.get(id)
    if existing then return existing end

    local def = defs[id]
    if not def then return nil end

    local stored = Db.load(id, 'stash')

    -- Db.load yields; another open may have created it meanwhile — reuse it so
    -- two callers never load two separate copies.
    existing = Inventory.get(id)
    if existing then return existing end

    local inv = Inventory.create(id, {
        type = 'stash',
        owner = id,
        label = def.label,
        slots = def.slots,
        maxWeight = def.weight,
        items = stored,
        persist = true,
    })

    Utils.log('debug', 'stash loaded', id)
    return inv
end

-- Load definitions from config.
for i = 1, #StashDefs do register(StashDefs[i]) end

exports('RegisterStash', function(def) return register(def) end)

return Stashes
