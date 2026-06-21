local Config = require 'config.config'

--- Notification abstraction. Uses ox_lib's notifications when ox_lib is on the
--- server; otherwise our own themed NUI notifications (built into the inventory
--- UI) — never the native GTA feed. 'custom' forwards to your own system.
local Notify = {}

local function provider()
    local p = Config.notify.provider
    if p == 'oxlib' or p == 'interface' or p == 'custom' then return p end
    -- auto: ox_lib if present, else our own interface.
    if GetResourceState('ox_lib') == 'started' and lib and lib.notify then
        return 'oxlib'
    end
    return 'interface'
end

--- @param data { title?: string, description: string, type?: 'success'|'error'|'inform', duration?: number }
function Notify.send(data)
    if type(data) ~= 'table' or not data.description then return end
    local p = provider()

    if p == 'oxlib' then
        lib.notify({
            title = data.title,
            description = data.description,
            type = data.type or 'inform',
            position = Config.notify.position,
            duration = data.duration,
        })
    elseif p == 'custom' then
        TriggerEvent('lk_inv:notification', data)
    else
        -- Our own NUI toast (SendNUIMessage works whether or not the inventory
        -- is open, and the toast layer renders regardless of focus).
        SendNUIMessage({ action = 'notify', data = data })
    end
end

RegisterNetEvent('lk_inv:notify_msg', function(data) Notify.send(data) end)

_G.LkNotify = Notify
return Notify
