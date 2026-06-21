--- Bridges server-pushed updates to the NUI: live slot refreshes (so multiple
--- players viewing the same stash stay in sync, and external AddItem/RemoveItem
--- reflect immediately) and slide-in item notifications.

RegisterNetEvent('lk_inv:refresh', function(payload)
    SendNUIMessage({ action = 'refreshSlots', data = payload })
end)

RegisterNetEvent('lk_inv:notify', function(data)
    SendNUIMessage({ action = 'itemNotify', data = data })
end)
