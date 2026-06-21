local Config = require 'config.config'
local Utils  = require 'shared.utils'
local Sound  = require 'client.sound'
local Locale = require 'shared.locale'

local Client = {
    uiLoaded = false,
    open = false,
    initSent = false,
    secondary = nil,
}
_G.LkClient = Client

local function screenBlurIn()
    if not Config.open.screenBlur then return end
    if IsScreenblurFadeRunning() then DisableScreenblurFade() end
    TriggerScreenblurFadeIn(100)
end

local function screenBlurOut()
    if not Config.open.screenBlur then return end
    if IsScreenblurFadeRunning() then DisableScreenblurFade() end
    TriggerScreenblurFadeOut(150)
end

--- Open the inventory, optionally alongside a secondary container (drop/stash).
function Client.openInventory(secondaryId)
    if Client.open or not Client.uiLoaded then return end

    local data = lib.callback.await('lk_inv:open', false, secondaryId)
    if not data then return end

    Client.open = true
    Client.secondary = secondaryId

    if not Client.initSent then
        SendNUIMessage({
            action = 'init',
            data = {
                locale = Locale.all(),
                items = data.items,
                imagepath = data.imagepath,
                leftInventory = data.left,
            },
        })
        Client.initSent = true
    end

    SendNUIMessage({
        action = 'setupInventory',
        data = { leftInventory = data.left, rightInventory = data.right },
    })

    SetNuiFocus(true, true)
    screenBlurIn()
    Sound.play('open')
end

function Client.closeInventory()
    if not Client.open then return end
    Client.open = false
    Client.secondary = nil

    SetNuiFocus(false, false)
    screenBlurOut()
    SendNUIMessage({ action = 'closeInventory' })
    TriggerServerEvent('lk_inv:closeInventory')
    Sound.play('close')
end

RegisterCommand(Config.open.command, function()
    if Client.open then Client.closeInventory() else Client.openInventory() end
end, false)

if Config.open.keybind and Config.open.keybind ~= '' then
    RegisterKeyMapping(Config.open.command, 'Open inventory', 'keyboard', Config.open.keybind)
end

-- Hotbar quick-use: number keys 1-5 use the item in that slot while the
-- inventory is closed, and flash the hotbar HUD.
for i = 1, 5 do
    local cmd = ('lk_inv_hotbar%d'):format(i)
    RegisterCommand(cmd, function()
        if Client.open or not Client.uiLoaded then return end
        SendNUIMessage({ action = 'toggleHotbar' })
        SendNUIMessage({ action = 'setActiveHotbarSlot', data = i })
        lib.callback('lk_inv:useItem', false, function() end, i)
    end, false)
    RegisterKeyMapping(cmd, ('Use hotbar slot %d'):format(i), 'keyboard', tostring(i))
end

-- Game-side close on ESC / Backspace (reliable under NUI focus, unlike relying
-- only on the browser keydown).
CreateThread(function()
    while true do
        if Client.open then
            DisableControlAction(0, 200, true) -- ESC
            if IsDisabledControlJustReleased(0, 200) or IsControlJustReleased(0, 177) then
                Client.closeInventory()
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and Client.open then
        SetNuiFocus(false, false)
        screenBlurOut()
    end
end)

return Client
