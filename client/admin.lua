local Notify = require 'client.notify'
local Locale = require 'shared.locale'

--- Opens the in-game audit panel (server gates access by ACE permission). The
--- `/lk_snapshots` and `/lk_rollback` admin commands are registered server-side
--- (work from the console and in-game for permitted admins).
RegisterCommand('lk_audit', function()
    local entries = lib.callback.await('lk_inv:getAudit', false)
    if entries == false then
        Notify.send({ type = 'error', description = Locale.t('no_permission') })
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAudit', data = { entries = entries } })
end, false)

RegisterNUICallback('closeAudit', function(_, cb)
    SetNuiFocus(false, false)
    cb(1)
end)
