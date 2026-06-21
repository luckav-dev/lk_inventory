local Config = require 'config.config'
local Client = require 'client.main'

--- Client-side ox_inventory compatibility. Combined with `provide 'ox_inventory'`
--- and the server-side compat exports, scripts that call exports.ox_inventory:...
--- on the client work against this resource unchanged.
if not (Config.compat and Config.compat.oxinventory) then return end

-- Live name->count mirror of the player's inventory (pushed by the server).
local items = {}
RegisterNetEvent('lk_inv:items', function(map)
    items = map or {}
end)

local function oxExport(name, fn)
    exports(name, fn)
    AddEventHandler(('__cfx_export_ox_inventory_%s'):format(name), function(setCB) setCB(fn) end)
end

oxExport('GetItemCount', function(item)
    return items[item] or 0
end)

oxExport('Search', function(search, item)
    if search == 'count' then
        if type(item) == 'table' then
            local out = {}
            for i = 1, #item do out[i] = items[item[i]] or 0 end
            return out
        end
        return items[item] or 0
    end
    return {}
end)

oxExport('GetPlayerItems', function()
    return items
end)

--- Open an inventory programmatically. Mirrors ox's openInventory(type, data):
--- a stash/shop/etc. id in `data.id`, or the player's own inventory.
oxExport('openInventory', function(invType, data)
    if invType == 'player' or not data then
        Client.openInventory()
    else
        Client.openInventory(data.id or invType)
    end
end)

oxExport('closeInventory', function()
    Client.closeInventory()
end)
