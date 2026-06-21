local Config    = require 'config.config'
local Locale = require 'shared.locale'
local StashDefs = require 'config.stashes'
local Client    = require 'client.main'

--- Creates a "press E to open" point for every stash that defines coords, and
--- exposes an export so other resources can open a stash by id.

local function makePoint(def)
    if not def.coords then return end

    local point = lib.points.new({
        coords = def.coords,
        distance = 8.0,
        stashId = def.id,
        label = def.label,
    })

    function point:nearby()
        if self.currentDistance > Config.drops.interactDist then
            if self.showing then lib.hideTextUI(); self.showing = false end
            return
        end

        if not self.showing then
            lib.showTextUI(Locale.t('hint_open', self.label or 'Open'), { position = 'left-center' })
            self.showing = true
        end

        if IsControlJustReleased(0, 38) and not Client.open then
            lib.hideTextUI(); self.showing = false
            Client.openInventory(self.stashId)
        end
    end
end

CreateThread(function()
    for i = 1, #StashDefs do makePoint(StashDefs[i]) end
end)

--- Open any registered stash by id (e.g. personal stashes created at runtime).
exports('OpenStash', function(id)
    Client.openInventory(id)
end)
