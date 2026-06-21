local Config    = require 'config.config'
local Locale = require 'shared.locale'
local BenchDefs = require 'config.crafting'
local Client    = require 'client.main'

--- "Press E to craft" points for benches with coords, plus an export to open a
--- bench by id.

local function makePoint(def)
    if not def.coords then return end

    local point = lib.points.new({
        coords = def.coords,
        distance = 8.0,
        benchId = def.id,
        label = def.label,
    })

    function point:nearby()
        if self.currentDistance > Config.drops.interactDist then
            if self.showing then lib.hideTextUI(); self.showing = false end
            return
        end

        if not self.showing then
            lib.showTextUI(Locale.t('hint_open', self.label or 'Craft'), { position = 'left-center' })
            self.showing = true
        end

        if IsControlJustReleased(0, 38) and not Client.open then
            lib.hideTextUI(); self.showing = false
            Client.openInventory(self.benchId)
        end
    end
end

CreateThread(function()
    for i = 1, #BenchDefs do makePoint(BenchDefs[i]) end
end)

exports('OpenCraftingBench', function(id)
    Client.openInventory(id)
end)
