local Config    = require 'config.config'
local Items     = require 'config.items'
local Utils     = require 'shared.utils'
local Locale    = require 'shared.locale'
local Db        = require 'server.db'
local Framework = require 'server.framework'
local Inventory = require 'server.inventory'
local Transfer  = require 'server.transfer'
local Drops     = require 'server.drops'
local Stashes   = require 'server.stashes'
local Shops     = require 'server.shops'
local Crafting  = require 'server.crafting'
local Money     = require 'server.money'
local Security  = require 'server.security'
local Logs      = require 'server.logs'
local Metrics   = require 'server.metrics'
local Dupe      = require 'server.dupe'
local Snapshots = require 'server.snapshots'

--- Admin gate for audit/rollback (ACE permission; console is always allowed).
local function isAdmin(source)
    return source == 0 or IsPlayerAceAllowed(source, Config.admin.ace)
end

--- Send a notification to a client through the pluggable notify layer.
local function notifyClient(source, description, ntype, title)
    TriggerClientEvent('lk_inv:notify_msg', source,
        { description = description, type = ntype or 'inform', title = title })
end

--- Trunk/glovebox capacity for a vehicle, by model override → class → default.
local function vehicleSpace(class, model, vtype)
    local cfg = Config.vehicles
    local space = (model and cfg.modelSpace[model]) or cfg.classSpace[class] or cfg.default
    local s = (vtype == 'glovebox' and (space.glove or cfg.default.glove))
        or (space.trunk or cfg.default.trunk)
    return s.slots, s.weight
end

--- True if the player meets any of the required group/grade pairs.
local function hasAnyGroup(source, groups)
    local pg = Framework.getGroups(source) or {}
    for name, minGrade in pairs(groups) do
        local g = pg[name]
        if g ~= nil and g >= (minGrade or 0) then return true end
    end
    return false
end

-- source -> ownerId, and source -> currently open secondary inventory id
local owners = {}
local openSecondary = {}

-- Open authorization: opening another player's body, a vehicle trunk, etc. must
-- be granted by the matching prep step (proximity/condition checked there) so a
-- client can't open arbitrary inventories by guessing ids.
local pendingOpen = {}        -- source -> authorized secondary id
local searchable = {}         -- source -> true when frisk-able (cuffed/hands up)
local dumpsterSearched = {}   -- dumpster id -> last search time
local pinUnlocked = {}        -- source -> { stashId -> true }
local pendingThrow = {}       -- source -> { name, count, metadata } mid-throw

local HIDDEN = { slots = 20, weight = 60000 } -- buried world-stash size

local function authorize(source, id)
    pendingOpen[source] = id
end

--- Is this stash PIN-locked and not yet unlocked by `source`?
local function stashLocked(source, inv)
    if not inv or inv.type ~= 'stash' then return false end
    local def = Stashes.getDef(inv.id)
    if not def or not def.pin then return false end
    return not (pinUnlocked[source] and pinUnlocked[source][inv.id])
end

--- May `source` open this secondary inventory right now?
local function isAuthorized(source, id, secondary)
    local t = secondary.type
    if t == 'player' then
        return id == source or pendingOpen[source] == id
    elseif t == 'trunk' or t == 'glovebox' or t == 'dumpster' or t == 'hidden' then
        return pendingOpen[source] == id
    elseif t == 'drop' then
        local coords = Drops.getCoords(id)
        if not coords then return false end
        local ped = GetPlayerPed(source)
        return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= 3.0
    end
    -- stash (group-gated separately), shop, crafting and containers are public.
    return true
end

--- Push the given slot ids of an inventory to everyone currently viewing it.
local function pushSlots(inv, slotIds)
    if not inv or not next(inv.viewers) then return end

    local payload = {}
    for i = 1, #slotIds do
        payload[i] = inv:slotPayload(slotIds[i])
    end

    for source in pairs(inv.viewers) do
        TriggerClientEvent('lk_inv:refresh', source, { items = payload })
    end
end

--- Body equipment the client renders: holstered weapons + whether a bag is worn.
local function visualsFor(inv)
    local weapons, bag = {}, false
    for _, slot in pairs(inv.items) do
        local def = Inventory.itemDef(slot.name)
        if def then
            if def.weapon then weapons[#weapons + 1] = { name = slot.name } end
            if def.container then bag = true end
        end
    end
    return { weapons = weapons, bag = bag }
end

--- Send the player's weight ratio (movement penalty), body visuals, and a
--- name->count map (so client-side ox_inventory-compat exports can read it).
local function pushWeight(source)
    local inv = Inventory.get(source)
    if not inv then return end
    local ratio = inv.maxWeight > 0 and (inv.weight / inv.maxWeight) or 0
    TriggerClientEvent('lk_inv:weight', source, ratio)
    TriggerClientEvent('lk_inv:visuals', source, visualsFor(inv))

    local counts = {}
    for _, slot in pairs(inv.items) do
        counts[slot.name] = (counts[slot.name] or 0) + slot.count
    end
    TriggerClientEvent('lk_inv:items', source, counts)
end

--- When a container's contents change, refresh the holder's container slot and
--- recompute their total weight (container weight propagation).
local function updateContainerParent(containerId)
    if not Inventory.get(containerId) then return end
    for src, secId in pairs(openSecondary) do
        if secId == containerId then
            local pInv = Inventory.get(src)
            if pInv then
                for slotId, slot in pairs(pInv.items) do
                    if slot.metadata and slot.metadata.container == containerId then
                        pInv:recalcWeight()
                        pInv.dirty = true
                        pushSlots(pInv, { slotId })
                        pushWeight(src)
                    end
                end
            end
        end
    end
end

--- Fire a slide-in item notification on a client. kind: 'ui_added'|'ui_removed'.
local function notify(source, name, kind, count)
    if not source then return end
    local def = Inventory.itemDef(name)
    TriggerClientEvent('lk_inv:notify', source,
        { { name = name, label = def and def.label or name }, kind, count })
end

--- Total count of `name` carried across all slots (money is the `money` item).
local function itemCount(inv, name)
    local total = 0
    for _, slot in pairs(inv.items) do
        if slot.name == name then total = total + slot.count end
    end
    return total
end

--- Remove `amount` of `name` across slots, appending changed slot ids to `acc`.
--- @return integer[] changed slot ids
local function removeByName(inv, name, amount, acc)
    acc = acc or {}
    for slotId, slot in pairs(inv.items) do
        if amount <= 0 then break end
        if slot.name == name then
            local take = math.min(slot.count, amount)
            inv:removeFromSlot(slotId, take)
            amount = amount - take
            acc[#acc + 1] = slotId
        end
    end
    return acc
end

--- Item registry in the shape the NUI expects.
local clientItems = (function()
    local out = {}
    for name, def in pairs(Items) do
        out[name] = {
            name = name,
            label = def.label or name,
            stack = def.stack ~= false,
            usable = def.usable == true,
            close = def.close == true,
            count = 0,
            weight = def.weight or 0,
            description = def.description,
            image = def.image,
            ammoName = def.ammoName,
            weapon = def.weapon == true,
            ammo = def.ammo == true,
            component = def.component == true,
            type = def.type,
        }
    end
    return out
end)()

MySQL.ready(Db.init)

--- Load (or create) a player's inventory when they spawn.
Framework.onLoaded(function(source, ownerId, name)
    -- Guard against double-loading (e.g. startup loop + load event racing).
    if owners[source] == ownerId and Inventory.get(source) then return end

    owners[source] = ownerId
    local stored = Db.load(ownerId, 'player')

    Inventory.create(source, {
        type = 'player',
        owner = ownerId,
        label = name,
        slots = Config.playerSlots,
        maxWeight = Config.playerWeight,
        items = stored,
    })

    Drops.syncTo(source)
    Snapshots.loadFor(source, ownerId)
    Utils.log('info', ('loaded inventory for %s (%s)'):format(name, ownerId))

    -- Render body visuals (holstered weapons / backpack) once the client is up.
    SetTimeout(1500, function() pushWeight(source) end)
end)

local function savePlayer(source)
    local inv = Inventory.get(source)
    local ownerId = owners[source]
    if inv and ownerId then
        local list = {}
        for _, slot in pairs(inv.items) do list[#list + 1] = slot end
        Db.save(ownerId, 'player', list)
    end
end

Framework.onDropped(function(source)
    savePlayer(source)

    -- Drop the player from any secondary container they were viewing.
    local secondaryId = openSecondary[source]
    if secondaryId then
        local secondary = Inventory.get(secondaryId)
        if secondary then secondary:removeViewer(source) end
    end

    Inventory.remove(source)
    owners[source] = nil
    openSecondary[source] = nil
    pendingOpen[source] = nil
    searchable[source] = nil
    pinUnlocked[source] = nil
    pendingThrow[source] = nil
    Snapshots.clear(source)
    Security.clear(source)
end)

--- Periodic flush of dirty inventories (players and persistent stashes).
CreateThread(function()
    while true do
        Wait(Config.saveInterval)
        for id, inv in pairs(Inventory.all()) do
            if inv.dirty then
                if inv.type == 'player' then
                    savePlayer(id)
                elseif inv.persist and inv.owner then
                    local list = {}
                    for _, slot in pairs(inv.items) do list[#list + 1] = slot end
                    Db.save(inv.owner, inv.type, list)
                end
                inv.dirty = false
            end
        end

        -- Unload idle, empty transient inventories (bags reload from the DB on
        -- next open; dumpsters regenerate loot after their cooldown).
        for id, inv in pairs(Inventory.all()) do
            if (inv.type == 'container' or inv.type == 'dumpster' or inv.type == 'hidden')
                and not next(inv.viewers) and not next(inv.items) then
                Inventory.remove(id)
            end
        end
    end
end)

----------------------------------------------------------------------
-- Anti-dupe scanning + snapshots/rollback + admin audit
----------------------------------------------------------------------

-- Periodic duplication scan: the same unique instance in two places is a dupe.
CreateThread(function()
    if not Config.dupe.enabled then return end
    while true do
        Wait(Config.dupe.interval)
        for _, d in ipairs(Dupe.scan()) do
            Metrics.inc('dupes_flagged')
            Logs.action('dupe', nil,
                ('duplicate %s [%s] in %s/slot %s'):format(d.name, d.id, tostring(d.invId), tostring(d.slotId)))
            TriggerEvent('lk_inv:dupe', d.invId, d.slotId, d.id, d.name)

            if Config.dupe.autoRemove then
                local inv = Inventory.get(d.invId)
                local slot = inv and inv.items[d.slotId]
                if slot then
                    inv:removeFromSlot(d.slotId, slot.count)
                    pushSlots(inv, { d.slotId })
                    if inv.type == 'player' then pushWeight(d.invId) end
                end
            end
        end
    end
end)

-- Periodic inventory snapshots for rollback.
CreateThread(function()
    if not Config.snapshots.enabled then return end
    while true do
        Wait(Config.snapshots.interval)
        for id, inv in pairs(Inventory.all()) do
            if inv.type == 'player' then Snapshots.take(id) end
        end
    end
end)

--- Restore a player's inventory to a snapshot and re-sync them. Returns ok.
local function doRollback(adminSource, target, index)
    if not Snapshots.restore(target, index) then return false end

    local inv = Inventory.get(target)
    if inv then
        local all = {}
        for i = 1, inv.slots do all[i] = i end
        pushSlots(inv, all)
        pushWeight(target)
        savePlayer(target)
    end

    Metrics.inc('rollbacks')
    Logs.action('rollback', adminSource, ('rolled back player %s to snapshot %d'):format(target, index))
    return true
end

lib.callback.register('lk_inv:getAudit', function(source)
    if not isAdmin(source) then return false end
    return Logs.recent()
end)

lib.callback.register('lk_inv:listSnapshots', function(source, targetId)
    if not isAdmin(source) then return {} end
    return Snapshots.list(tonumber(targetId) or source)
end)

lib.callback.register('lk_inv:rollback', function(source, data)
    if not isAdmin(source) or type(data) ~= 'table' then return false end
    return doRollback(source, tonumber(data.target) or source, tonumber(data.index) or 1)
end)

RegisterCommand('lk_snapshots', function(source, args)
    if not isAdmin(source) then return end
    local target = tonumber(args[1])
    if not target then return print('usage: lk_snapshots <playerId>') end
    print(('^5[lk_inv] snapshots for %s:^0'):format(target))
    for _, s in ipairs(Snapshots.list(target)) do
        print(('  [%d] %d slots — %s'):format(s.index, s.slots, tostring(s.at)))
    end
end, false)

RegisterCommand('lk_rollback', function(source, args)
    if not isAdmin(source) then return end
    local target, index = tonumber(args[1]), tonumber(args[2]) or 1
    if not target then return print('usage: lk_rollback <playerId> <index>') end
    if doRollback(source, target, index) then
        print(('^2[lk_inv] rolled back %s to snapshot %d^0'):format(target, index))
    else
        print('^1[lk_inv] rollback failed (no such player/snapshot)^0')
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id, inv in pairs(Inventory.all()) do
        if inv.type == 'player' then
            savePlayer(id)
        elseif inv.persist and inv.owner then
            local list = {}
            for _, slot in pairs(inv.items) do list[#list + 1] = slot end
            Db.save(inv.owner, inv.type, list)
        end
    end
end)

----------------------------------------------------------------------
-- NUI-facing callbacks (the client forwards UI fetchNui calls here)
----------------------------------------------------------------------

--- Resolve a from/to type string to a concrete inventory for `source`.
local function resolve(source, invType)
    if invType == 'player' then return Inventory.get(source) end
    local secondary = openSecondary[source]
    return secondary and Inventory.get(secondary) or nil
end

lib.callback.register('lk_inv:open', function(source, secondaryId)
    local inv = Inventory.get(source)
    if not inv then return nil end

    inv:addViewer(source)

    -- Keep the money item in sync with the framework account for display.
    Money.syncItem(source)

    local right
    if secondaryId then
        -- A live container (drop/bag), a registered stash, a shop, or a bench.
        local secondary = Inventory.get(secondaryId)
            or Stashes.ensure(secondaryId)
            or Shops.ensure(secondaryId)
            or Crafting.ensure(secondaryId)

        -- Stash job/group access control.
        if secondary and secondary.type == 'stash' then
            local def = Stashes.getDef(secondaryId)
            if def and def.groups and not hasAnyGroup(source, def.groups) then
                secondary = nil
            end
        end

        -- Authorization gate (prevents opening arbitrary players/trunks).
        if secondary and not isAuthorized(source, secondaryId, secondary) then
            secondary = nil
        end
        pendingOpen[source] = nil

        if secondary then
            openSecondary[source] = secondaryId
            secondary:addViewer(source)
            right = secondary:toClient()
        else
            openSecondary[source] = nil
        end
    else
        openSecondary[source] = nil
    end

    pushWeight(source)

    return {
        items = clientItems,
        imagepath = ('nui://%s/web/images'):format(GetCurrentResourceName()),
        left = inv:toClient(),
        right = right,
    }
end)

lib.callback.register('lk_inv:swap', function(source, data)
    if type(data) ~= 'table' then return false end

    local action = data.toType == 'newdrop' and 'drop' or 'swap'
    if not Security.allow(source, action) then
        Security.flag(source, action .. ' rate exceeded')
        Metrics.inc('exploit_flags')
        return false
    end

    -- Drop to ground: client provides validated player coords.
    if data.toType == 'newdrop' then
        local from = Inventory.get(source)
        local slot = from and from.items[data.fromSlot]
        if not slot or not data.coords then return false end

        local count = math.min(data.count or slot.count, slot.count)
        local dropId = Drops.create(data.coords, slot.name, count, slot.metadata, source)
        if not dropId then return false end

        from:removeFromSlot(data.fromSlot, count)
        pushSlots(from, { data.fromSlot })
        pushWeight(source)
        Logs.action('drop', source, ('dropped %dx %s'):format(count, slot.name))
        Metrics.inc('drops_created')
        return true
    end

    local from = resolve(source, data.fromType)
    local to   = resolve(source, data.toType)
    if not from or not to then return false end

    -- Anti-exploit: read-only containers are handled by buy/craft, not drag.
    if from.type == 'shop' or to.type == 'shop'
        or from.type == 'crafting' or to.type == 'crafting' then
        return false
    end

    -- PIN-locked stashes must be unlocked before items can move.
    if stashLocked(source, from) or stashLocked(source, to) then return false end

    local ok = Transfer.move(from, data.fromSlot, to, data.toSlot, data.count)
    if not ok then return false end

    -- Keep every viewer of both containers in sync.
    pushSlots(from, { data.fromSlot })
    pushSlots(to, { data.toSlot })

    -- Container weight propagation to the holding inventory.
    if from.type == 'container' then updateContainerParent(from.id) end
    if to.type == 'container' then updateContainerParent(to.id) end

    pushWeight(source)
    Metrics.inc('swaps')

    -- Clean up emptied drops
    if from.type == 'drop' and not next(from.items) then
        Drops.remove(from.id)
    end

    return true
end)

lib.callback.register('lk_inv:buyItem', function(source, data)
    if type(data) ~= 'table' then return false end

    local shopId = openSecondary[source]
    local shop = shopId and Inventory.get(shopId)
    if not shop or shop.type ~= 'shop' then return false end

    local shopSlot = shop.items[data.fromSlot]
    if not shopSlot then return false end

    local player = Inventory.get(source)
    if not player then return false end

    local count = math.max(1, math.floor(data.count or 1))
    local price = (shopSlot.price or 0) * count
    local buyWeight = Inventory.slotWeight(shopSlot.name, count)

    local account = shopSlot.currency == 'bank' and 'bank' or 'cash'
    if not Money.afford(source, price, account) then return false end
    if not player:canHold(buyWeight) then return false end

    local ok, moneyChanged = Money.chargeAccount(source, price, account)
    if not ok then return false end

    local target = player:findStack(shopSlot.name, {}) or player:firstFree()
    if not target or not player:addItem(shopSlot.name, count, {}) then
        -- Refund: the player was charged but couldn't receive the item.
        Money.refund(source, price, account)
        pushSlots(player, moneyChanged)
        pushWeight(source)
        return false
    end

    pushSlots(player, moneyChanged)
    pushSlots(player, { target })
    pushWeight(source)
    notify(source, shopSlot.name, 'ui_added', count)
    Logs.action('buy', source, ('bought %dx %s for %d (%s)'):format(count, shopSlot.name, price, account))
    Metrics.inc('buys')
    return true
end)

lib.callback.register('lk_inv:craftItem', function(source, data)
    if type(data) ~= 'table' then return false end

    local benchId = openSecondary[source]
    local bench = benchId and Inventory.get(benchId)
    if not bench or bench.type ~= 'crafting' then return false end

    local recipe = bench.items[data.fromSlot]
    if not recipe then return false end

    local player = Inventory.get(source)
    if not player then return false end

    local count = math.max(1, math.floor(data.count or 1))
    local ingredients = recipe.ingredients or {}
    local resultCount = (recipe.count or 1) * count

    -- Verify the player has every ingredient.
    for name, req in pairs(ingredients) do
        if itemCount(player, name) < req * count then return false end
    end

    -- Net weight feasibility (ingredients are removed, result is added).
    local ingWeight = 0
    for name, req in pairs(ingredients) do
        ingWeight = ingWeight + Inventory.slotWeight(name, req * count)
    end
    local resultWeight = Inventory.slotWeight(recipe.name, resultCount)
    if player.weight - ingWeight + resultWeight > player.maxWeight then return false end

    -- Quality/success roll — materials are consumed either way.
    local success = not recipe.successChance or math.random() <= recipe.successChance

    local changed = {}
    for name, req in pairs(ingredients) do
        removeByName(player, name, req * count, changed)
    end

    if not success then
        pushSlots(player, changed)
        pushWeight(source)
        notifyClient(source, Locale.t('crafting_failed'), 'error')
        Logs.action('craft', source, ('failed crafting %s'):format(recipe.name))
        return true
    end

    local target = player:findStack(recipe.name, {}) or player:firstFree()
    if not target or not player:addItem(recipe.name, resultCount, {}) then
        -- Couldn't deliver the result: give the ingredients back.
        for name, req in pairs(ingredients) do player:addItem(name, req * count, {}) end
        pushWeight(source)
        return false
    end
    changed[#changed + 1] = target

    pushSlots(player, changed)
    pushWeight(source)
    notify(source, recipe.name, 'ui_added', resultCount)
    Logs.action('craft', source, ('crafted %dx %s'):format(resultCount, recipe.name))
    Metrics.inc('crafts')
    return true
end)

--- Validate a vehicle storage request and load the container keyed by plate.
--- Returns the container id the client should then open, or nil.
lib.callback.register('lk_inv:prepVehicle', function(source, data)
    if type(data) ~= 'table' or not data.netId then return nil end

    local entity = NetworkGetEntityFromNetworkId(data.netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    -- Anti-exploit: the player must actually be next to the vehicle.
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(entity)) > 8.0 then
        return nil
    end

    local plate = GetVehicleNumberPlateText(entity)
    plate = plate and plate:gsub('%s+$', '') or ''
    if plate == '' then return nil end

    local vtype = data.vtype == 'glovebox' and 'glovebox' or 'trunk'
    local id = ('%s_%s'):format(vtype, plate)

    if not Inventory.get(id) then
        -- Derive the class on the server (don't trust the client, or a bike
        -- could claim a truck-sized trunk); fall back to the client value only
        -- if the server native is unavailable.
        local class = GetVehicleClass(entity)
        if not class or class < 0 then class = tonumber(data.class) or -1 end
        local model = data.model and tostring(data.model):lower() or nil
        local slots, weight = vehicleSpace(class, model, vtype)

        local stored = Db.load(id, vtype) -- yields; re-check before creating
        if not Inventory.get(id) then
            Inventory.create(id, {
                type = vtype,
                owner = id,
                label = ('%s %s'):format(vtype == 'trunk' and 'Trunk' or 'Glovebox', plate),
                slots = slots,
                maxWeight = weight,
                items = stored,
                persist = true,
            })
        end
    end

    authorize(source, id)
    return id
end)

--- Current cargo load (0..1) of a vehicle's trunk, for the handling penalty.
--- Does not force-load the trunk (returns 0 when it hasn't been opened).
lib.callback.register('lk_inv:trunkLoad', function(source, plate)
    if not plate then return 0 end
    local inv = Inventory.get(('trunk_%s'):format(tostring(plate):gsub('%s+$', '')))
    if not inv or inv.maxWeight <= 0 then return 0 end
    return math.min(inv.weight / inv.maxWeight, 1.0)
end)

--- Mark yourself frisk-able (set by cuff / hands-up scripts). Exposed as an
--- export so other resources can flag a player too.
RegisterNetEvent('lk_inv:setSearchable', function(state)
    searchable[source] = state and true or nil
end)
exports('SetSearchable', function(target, state)
    searchable[target] = state and true or nil
end)

--- Frisk/search a nearby player. Allowed when the target is down (dead) or has
--- been flagged searchable, and is within reach.
lib.callback.register('lk_inv:searchPlayer', function(source, targetId)
    targetId = tonumber(targetId)
    if not targetId or targetId == source then return false end
    if not Security.allow(source, 'use') then return false end

    local sPed, tPed = GetPlayerPed(source), GetPlayerPed(targetId)
    if sPed == 0 or tPed == 0 then return false end
    if #(GetEntityCoords(sPed) - GetEntityCoords(tPed)) > 2.5 then return false end

    -- Searchable state is set by death/cuff/hands-up scripts via the
    -- SetSearchable export (server-side GetEntityHealth is unreliable under
    -- OneSync, so we don't infer "down" ourselves — other resources tell us).
    if not searchable[targetId] then return false end
    if not Inventory.get(targetId) then return false end

    authorize(source, targetId)
    Logs.action('frisk', source, ('searched player %s'):format(targetId))
    Metrics.inc('frisks')
    return targetId
end)

--- Search a dumpster. The client sends the prop coords; the server generates
--- loot the first time (with a cooldown) and authorizes opening it.
lib.callback.register('lk_inv:searchDumpster', function(source, coords)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return false end
    if not Security.allow(source, 'use') then return false end

    local pos = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - pos) > 3.0 then return false end

    local Dump = require 'config.dumpsters'
    local id = ('dump_%d_%d_%d'):format(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z))

    local inv = Inventory.get(id)
    if not inv then
        local last = dumpsterSearched[id]
        local fresh = not last or (GetGameTimer() - last) > Dump.cooldown
        inv = Inventory.create(id, {
            type = 'dumpster', label = 'Dumpster',
            slots = Dump.slots, maxWeight = Dump.weight, items = {},
        })
        if fresh then
            for _, entry in ipairs(Dump.loot) do
                if math.random() <= entry.chance then
                    inv:addItem(entry.name, math.random(entry.min, entry.max))
                end
            end
            dumpsterSearched[id] = GetGameTimer()
        end
    end

    authorize(source, id)
    Logs.action('dumpster', source, 'searched a dumpster')
    Metrics.inc('dumpsters')
    return id
end)

----------------------------------------------------------------------
-- PIN-locked stashes (drives the existing PIN overlay in the UI)
----------------------------------------------------------------------

lib.callback.register('lk_inv:checkPin', function(source, stashId)
    local def = Stashes.getDef(stashId)
    local required = def and def.pin ~= nil
    local unlocked = not required or (pinUnlocked[source] and pinUnlocked[source][stashId]) or false
    return { required = required, unlocked = unlocked, label = def and def.label }
end)

lib.callback.register('lk_inv:unlockPin', function(source, data)
    local stashId = type(data) == 'table' and data.stash or nil
    local def = stashId and Stashes.getDef(stashId)
    if not def or not def.pin then return { success = true } end

    if tostring(data.pin or '') == tostring(def.pin) then
        pinUnlocked[source] = pinUnlocked[source] or {}
        pinUnlocked[source][stashId] = true
        return { success = true }
    end
    return { success = false, error = Locale.t('wrong_pin') }
end)

----------------------------------------------------------------------
-- Hidden world stashes (buried caches): keyed by a world grid cell.
----------------------------------------------------------------------

local function cellId(coords)
    return ('hidden_%d_%d_%d'):format(math.floor(coords.x), math.floor(coords.y), math.floor(coords.z))
end

local function ensureHidden(id)
    local inv = Inventory.get(id)
    if inv then return inv end
    local stored = Db.load(id, 'hidden') -- yields
    inv = Inventory.get(id)
    if inv then return inv end
    return Inventory.create(id, {
        type = 'hidden', owner = id, label = 'Stash',
        slots = HIDDEN.slots, maxWeight = HIDDEN.weight,
        items = stored, persist = true,
    })
end

--- Bury/place a hidden stash at your position.
lib.callback.register('lk_inv:hideStash', function(source, coords)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return false end
    local ped = GetPlayerPed(source)
    local pos = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    if ped == 0 or #(GetEntityCoords(ped) - pos) > 3.0 then return false end

    local id = cellId(pos)
    local inv = ensureHidden(id)
    inv.dirty = true
    Db.save(id, 'hidden', {}) -- register the cell so it can be found later
    authorize(source, id)
    Logs.action('stash', source, 'placed a hidden stash')
    return id
end)

--- Search the ground at your position for a hidden stash.
lib.callback.register('lk_inv:searchGround', function(source, coords)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return false end
    local pos = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)

    -- The player must actually be at the spot (otherwise any buried cache could
    -- be opened remotely by guessing/replaying coordinates).
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - pos) > 3.0 then return false end

    local id = cellId(pos)
    if not Inventory.get(id) and not Db.exists(id, 'hidden') then return false end

    ensureHidden(id)
    authorize(source, id)
    return id
end)

----------------------------------------------------------------------
-- Pickpocketing: a stealth chance to lift one item from a nearby player.
----------------------------------------------------------------------

lib.callback.register('lk_inv:pickpocket', function(source, targetId)
    targetId = tonumber(targetId)
    if not targetId or targetId == source then return false end
    if not Security.allow(source, 'use') then return false end

    local sPed, tPed = GetPlayerPed(source), GetPlayerPed(targetId)
    if sPed == 0 or tPed == 0 then return false end
    if #(GetEntityCoords(sPed) - GetEntityCoords(tPed)) > 1.8 then return false end

    local thief, victim = Inventory.get(source), Inventory.get(targetId)
    if not thief or not victim then return false end

    -- Fail: alert the victim.
    if math.random() > (Config.pickpocket.chance or 0.5) then
        notifyClient(targetId, Locale.t('pickpocket_victim'), 'error')
        notifyClient(source, Locale.t('pickpocket_failed'), 'error')
        return false
    end

    -- Success: lift one random non-money item.
    local candidates = {}
    for slotId, slot in pairs(victim.items) do
        if slot.name ~= 'money' then candidates[#candidates + 1] = slotId end
    end
    if #candidates == 0 then return false end

    local key = candidates[math.random(#candidates)]
    local pick = victim.items[key]
    if not thief:canHold(Inventory.slotWeight(pick.name, 1)) then return false end

    local target = thief:findStack(pick.name, pick.metadata) or thief:firstFree()
    thief:addItem(pick.name, 1, Utils.clone(pick.metadata))
    victim:removeFromSlot(key, 1)
    if target then pushSlots(thief, { target }) end
    pushSlots(victim, { key })
    pushWeight(source); pushWeight(targetId)
    notifyClient(source, Locale.t('lifted_item', pick.name), 'success')
    Logs.action('frisk', source, ('pickpocketed %s from %s'):format(pick.name, targetId))
    return true
end)

----------------------------------------------------------------------
-- Throwing items by hand
----------------------------------------------------------------------

local function itemRender(name)
    local def = Inventory.itemDef(name)
    if def and def.weapon then return { weapon = name } end
    return { model = (def and def.ground) or Config.drops.fallbackModel }
end

--- Begin a throw: remove one item now (atomic, no dupe) and hand the client the
--- visual data. The drop is created where it lands (lk_inv:throwLand), with a
--- safety net so the item is never lost if the client never reports a landing.
lib.callback.register('lk_inv:throwItem', function(source, data)
    if not Config.throw.enabled then return false end
    if type(data) ~= 'table' then return false end
    if not Security.allow(source, 'drop') then return false end

    local inv = Inventory.get(source)
    local slot = inv and inv.items[data.slot]
    if not slot then return false end

    local name, meta = slot.name, slot.metadata
    inv:removeFromSlot(data.slot, 1)
    pushSlots(inv, { data.slot })
    pushWeight(source)

    pendingThrow[source] = { name = name, count = 1, metadata = meta }

    SetTimeout(Config.throw.settle + 4000, function()
        local pending = pendingThrow[source]
        if not pending then return end
        pendingThrow[source] = nil
        local ped = GetPlayerPed(source)
        if ped ~= 0 then
            Drops.create(GetEntityCoords(ped), pending.name, pending.count, pending.metadata, source)
        end
    end)

    return { name = name, metadata = meta, render = itemRender(name) }
end)

--- Move a ground drop after a player kicks it (client reports the new resting
--- spot; the server validates proximity to the old spot and re-broadcasts).
RegisterNetEvent('lk_inv:moveDrop', function(dropId, coords)
    local src = source
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end
    local old = Drops.getCoords(dropId)
    if not old then return end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - old) > 5.0 then return end
    Drops.move(dropId, vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0))
end)

RegisterNetEvent('lk_inv:throwLand', function(coords)
    local src = source
    local pending = pendingThrow[src]
    if not pending then return end
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end

    pendingThrow[src] = nil
    Drops.create(vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0),
        pending.name, pending.count, pending.metadata, src)
    Logs.action('drop', src, ('threw %s'):format(pending.name))
    Metrics.inc('throws')
end)

lib.callback.register('lk_inv:useItem', function(source, slotId)
    if not Security.allow(source, 'use') then return false end

    local inv = Inventory.get(source)
    local slot = inv and inv.items[slotId]
    if not slot then return false end

    local def = Inventory.itemDef(slot.name)
    if not def or not def.usable then return false end

    -- Weapon: client equips/holsters it.
    if def.weapon then
        return { weapon = { slot = slotId, name = slot.name, metadata = slot.metadata or {} } }
    end

    -- Component: client attaches it to the equipped weapon.
    if def.component then
        return { component = { slot = slotId, name = slot.name } }
    end

    -- Container (bag): open its own inventory, loading it on demand.
    if def.container then
        slot.metadata = slot.metadata or {}
        if not slot.metadata.container then
            slot.metadata.container = ('cont_%d_%d'):format(slotId, math.random(10000, 99999))
            inv.dirty = true
        end
        local cid = slot.metadata.container
        if not Inventory.get(cid) then
            Inventory.create(cid, {
                type = 'container', owner = cid, label = def.label or 'Container',
                slots = def.container.slots or 10, maxWeight = def.container.weight or 20000,
                items = Db.load(cid, 'container'), persist = true,
            })
        end
        return { open = cid }
    end

    -- Carriable heavy item: client picks it up in hand.
    if def.carry then
        return { carry = { slot = slotId, name = slot.name } }
    end

    -- Repair kit: the client repairs the equipped weapon (see lk_inv:repairWeapon).
    if def.repair then
        return { repair = { slot = slotId } }
    end

    -- Consumable. Consume the item first (so an external listener can't pull the
    -- slot out from under us), then relay effects to status/metabolism scripts —
    -- we never implement hunger/thirst ourselves, that belongs to another resource.
    local usedName = slot.name
    if slot.metadata and slot.metadata.uses and slot.metadata.uses > 1 then
        slot.metadata.uses = slot.metadata.uses - 1
        inv.dirty = true
        pushSlots(inv, { slotId })
    else
        inv:removeFromSlot(slotId, 1)
        pushSlots(inv, { slotId })
        notify(source, usedName, 'ui_removed', 1)
    end

    pushWeight(source)
    TriggerEvent('lk_inv:itemUsed', source, usedName, slot.metadata)
    if def.effects then
        TriggerClientEvent('lk_inv:useEffects', source, usedName, def.effects)
    end

    -- Tell the client which item was used so it can play the use animation.
    return { used = usedName }
end)

--- Repair the equipped weapon with a repair kit (client supplies both slots).
lib.callback.register('lk_inv:repairWeapon', function(source, data)
    if type(data) ~= 'table' then return false end
    local inv = Inventory.get(source)
    if not inv then return false end

    local kit = inv.items[data.kitSlot]
    local weapon = inv.items[data.weaponSlot]
    if not kit or not weapon then return false end

    local kdef = Inventory.itemDef(kit.name)
    local wdef = Inventory.itemDef(weapon.name)
    if not kdef or not kdef.repair or not wdef or not wdef.weapon then return false end

    weapon.metadata = weapon.metadata or {}
    weapon.metadata.durability = kdef.repair.amount or 100

    inv:removeFromSlot(data.kitSlot, 1)
    inv.dirty = true
    pushSlots(inv, { data.weaponSlot, data.kitSlot })
    Logs.action('craft', source, ('repaired %s'):format(weapon.name))
    return weapon.metadata.durability
end)

--- Persist a weapon's live state (ammo/durability/components) from the client.
RegisterNetEvent('lk_inv:syncWeapon', function(slotId, data)
    local src = source
    local inv = Inventory.get(src)
    local slot = inv and inv.items[slotId]
    if not slot or type(data) ~= 'table' then return end

    local def = Inventory.itemDef(slot.name)
    if not def or not def.weapon then return end

    slot.metadata = slot.metadata or {}
    if data.ammo ~= nil then slot.metadata.ammo = data.ammo end
    if data.durability ~= nil then slot.metadata.durability = data.durability end
    if data.components ~= nil then slot.metadata.components = data.components end
    inv.dirty = true
    pushSlots(inv, { slotId })
end)

--- Attach a component item to a weapon. Returns the component name to apply.
lib.callback.register('lk_inv:attachComponent', function(source, data)
    if type(data) ~= 'table' then return false end
    local inv = Inventory.get(source)
    if not inv then return false end

    local weapon = inv.items[data.weaponSlot]
    local comp = inv.items[data.componentSlot]
    if not weapon or not comp then return false end

    local wdef = Inventory.itemDef(weapon.name)
    local cdef = Inventory.itemDef(comp.name)
    if not wdef or not wdef.weapon or not cdef or not cdef.component then return false end

    weapon.metadata = weapon.metadata or {}
    weapon.metadata.components = weapon.metadata.components or {}
    weapon.metadata.components[#weapon.metadata.components + 1] = comp.name

    inv:removeFromSlot(data.componentSlot, 1)
    inv.dirty = true
    pushSlots(inv, { data.weaponSlot, data.componentSlot })
    return comp.name
end)

--- Remove a component from a weapon and return the item to the inventory.
lib.callback.register('lk_inv:removeComponent', function(source, data)
    if type(data) ~= 'table' then return false end
    local inv = Inventory.get(source)
    if not inv then return false end

    local weapon = inv.items[data.slot]
    if not weapon or not weapon.metadata or not weapon.metadata.components then return false end

    local comps = weapon.metadata.components
    local removed
    for i = #comps, 1, -1 do
        if comps[i] == data.component then
            table.remove(comps, i)
            removed = true
            break
        end
    end
    if not removed then return false end

    inv:addItem(data.component, 1, {})
    inv.dirty = true
    pushSlots(inv, { data.slot })
    return data.component
end)

lib.callback.register('lk_inv:getItemData', function(_, name)
    return clientItems[name]
end)

lib.callback.register('lk_inv:give', function(source, data)
    if type(data) ~= 'table' then return false end
    if not Security.allow(source, 'use') then return false end

    local target = data.target and tonumber(data.target)
    if not target or target == source then return false end

    -- Both players must be in reach (the target is resolved client-side, so the
    -- server must not trust it without a distance check).
    local sPed, tPed = GetPlayerPed(source), GetPlayerPed(target)
    if sPed == 0 or tPed == 0 then return false end
    if #(GetEntityCoords(sPed) - GetEntityCoords(tPed)) > 3.0 then return false end

    local from = Inventory.get(source)
    local to = Inventory.get(target)
    local slot = from and from.items[data.slot]
    if not from or not to or not slot then return false end

    local count = math.min(data.count or 1, slot.count)
    if count < 1 then return false end

    -- Cash uses the framework account when available.
    if slot.name == 'money' and Money.useFramework(source) then
        local amount = math.min(count, Money.get(source))
        if amount <= 0 then return false end
        if not Framework.removeMoney(source, 'cash', amount) then return false end
        Framework.addMoney(target, 'cash', amount)
        pushSlots(from, Money.syncItem(source))
        pushSlots(to, Money.syncItem(target))
        Logs.action('money', source, ('gave $%d to %s'):format(amount, target))
        Metrics.inc('money_given')
        return true
    end

    -- Clone metadata so the two inventories never share one table (a partial
    -- give would otherwise leave both slots aliasing one __uid).
    local before = to:findStack(slot.name, slot.metadata) or to:firstFree()
    if not to:addItem(slot.name, count, Utils.clone(slot.metadata)) then return false end
    from:removeFromSlot(data.slot, count)

    pushSlots(from, { data.slot })
    if before then pushSlots(to, { before }) end
    pushWeight(source)
    pushWeight(target)
    notify(target, slot.name, 'ui_added', count)
    Logs.action('give', source, ('gave %dx %s to %s'):format(count, slot.name, target))
    return true
end)

RegisterNetEvent('lk_inv:closeInventory', function()
    local src = source
    local inv = Inventory.get(src)
    if inv then inv:removeViewer(src) end

    local secondaryId = openSecondary[src]
    if secondaryId then
        local secondary = Inventory.get(secondaryId)
        if secondary then secondary:removeViewer(src) end
    end

    openSecondary[src] = nil
    pinUnlocked[src] = nil -- re-lock PIN stashes on next open
end)

----------------------------------------------------------------------
-- Public exports for other resources
----------------------------------------------------------------------

exports('AddItem', function(source, name, count, metadata)
    local inv = Inventory.get(source)
    if not inv then return false end

    -- Capture which slot ends up changed so open viewers refresh live.
    local before = inv:findStack(name, metadata) or inv:firstFree()
    local ok = inv:addItem(name, count, metadata)
    if ok then
        if before then pushSlots(inv, { before }) end
        pushWeight(source)
        notify(source, name, 'ui_added', count or 1)
        Metrics.inc('items_added', count or 1)
    end
    return ok
end)

exports('RemoveItem', function(source, slotId, count)
    local inv = Inventory.get(source)
    if not inv then return false end

    local slot = inv.items[slotId]
    local ok = inv:removeFromSlot(slotId, count)
    if ok then
        pushSlots(inv, { slotId })
        pushWeight(source)
        if slot then notify(source, slot.name, 'ui_removed', count or slot.count) end
        Metrics.inc('items_removed', count or 1)
    end
    return ok
end)

exports('GetInventory', function(source)
    local inv = Inventory.get(source)
    return inv and inv:toClient() or nil
end)

exports('CreateDrop', function(coords, name, count, metadata)
    return Drops.create(coords, name, count, metadata)
end)

exports('DeleteContainer', function(containerId)
    if not containerId then return false end
    Inventory.remove(containerId)
    Db.delete(containerId, 'container')
    return true
end)

exports('GetMoney', function(source)
    return Money.get(source)
end)

----------------------------------------------------------------------
-- ox_inventory-compatible exports. Combined with `provide 'ox_inventory'` in
-- the manifest, the existing script ecosystem (which calls
-- exports.ox_inventory:...) works against this resource with no edits.
----------------------------------------------------------------------
if Config.compat and Config.compat.oxinventory then
    -- Register a function under both lk_inv and ox_inventory export names.
    local function oxExport(name, fn)
        exports(name, fn)
        AddEventHandler(('__cfx_export_ox_inventory_%s'):format(name), function(setCB) setCB(fn) end)
    end

    oxExport('Items', function(item)
        if item then return clientItems[item] end
        return clientItems
    end)
    oxExport('ItemList', function(item)
        if item then return clientItems[item] end
        return clientItems
    end)

    oxExport('GetItemCount', function(inv, item)
        local i = Inventory.get(inv)
        return i and itemCount(i, item) or 0
    end)

    oxExport('GetInventory', function(inv)
        local i = Inventory.get(inv)
        return i and i:toClient() or nil
    end)

    oxExport('GetInventoryItems', function(inv)
        local i = Inventory.get(inv)
        return i and i:toClient().items or {}
    end)

    oxExport('GetSlot', function(inv, slotId)
        local i = Inventory.get(inv)
        return i and i.items[slotId] or nil
    end)

    oxExport('GetItem', function(inv, item, metadata, returnsCount)
        local i = Inventory.get(inv)
        if not i then return returnsCount and 0 or nil end
        if returnsCount then return itemCount(i, item) end
        for _, s in pairs(i.items) do
            if s.name == item then return s end
        end
    end)

    oxExport('GetSlotIdWithItem', function(inv, item)
        local i = Inventory.get(inv)
        if not i then return nil end
        for slotId, s in pairs(i.items) do
            if s.name == item then return slotId end
        end
    end)

    oxExport('CanCarryItem', function(inv, item, count)
        local i = Inventory.get(inv)
        if not i then return false end
        return i:canHold(Inventory.slotWeight(item, count or 1))
            and (i:findStack(item) or i:firstFree()) ~= nil
    end)

    oxExport('AddItem', function(inv, item, count, metadata, slot, cb)
        local i = Inventory.get(inv)
        if not i then if cb then cb(false) end return false end
        local target = i:findStack(item, metadata) or i:firstFree()
        local ok = i:addItem(item, count, metadata)
        if ok then
            if target then pushSlots(i, { target }) end
            pushWeight(inv)
            notify(inv, item, 'ui_added', count or 1)
            Metrics.inc('items_added', count or 1)
        end
        if cb then cb(ok) end
        return ok
    end)

    oxExport('RemoveItem', function(inv, item, count, metadata, slot, cb)
        local i = Inventory.get(inv)
        if not i then if cb then cb(false) end return false end
        count = count or 1
        if itemCount(i, item) < count then if cb then cb(false) end return false end
        local changed = removeByName(i, item, count)
        pushSlots(i, changed)
        pushWeight(inv)
        notify(inv, item, 'ui_removed', count)
        Metrics.inc('items_removed', count)
        if cb then cb(true) end
        return true
    end)

    oxExport('Search', function(inv, search, item)
        local i = Inventory.get(inv)
        if not i then return search == 'count' and 0 or {} end
        if search == 'count' then return itemCount(i, item) end
        local slots = {}
        for _, s in pairs(i.items) do
            if s.name == item then slots[#slots + 1] = s end
        end
        return slots
    end)

    oxExport('GetItemSlots', function(inv, item)
        local i = Inventory.get(inv)
        local slots, totalCount = {}, 0
        if i then
            for slotId, s in pairs(i.items) do
                if s.name == (type(item) == 'table' and item.name or item) then
                    slots[slotId] = s.count
                    totalCount = totalCount + s.count
                end
            end
        end
        return slots, totalCount
    end)

    Logs.action('stash', nil, 'ox_inventory compatibility exports enabled')
end
