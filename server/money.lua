local Framework = require 'server.framework'
local Inventory = require 'server.inventory'

--- Unified money layer. When the framework exposes account money (QBCore/ESX)
--- it is the source of truth and the in-inventory `money` item mirrors the cash
--- balance for display. Otherwise `money` is a plain item.
local Money = {}

local function countItem(inv, name)
    local total = 0
    for _, slot in pairs(inv.items) do
        if slot.name == name then total = total + slot.count end
    end
    return total
end

function Money.useFramework(source)
    return Framework.getMoney(source, 'cash') ~= nil
end

--- Make the player's `money` item equal the framework cash balance.
--- @return integer[] changed slot ids
function Money.syncItem(source)
    local inv = Inventory.get(source)
    if not inv then return {} end

    local balance = Framework.getMoney(source, 'cash')
    if balance == nil then return {} end

    local changed, primary = {}, nil
    for slotId, slot in pairs(inv.items) do
        if slot.name == 'money' then
            if not primary then
                primary = slotId
            else
                inv:removeFromSlot(slotId, slot.count)
                changed[#changed + 1] = slotId
            end
        end
    end

    if balance > 0 then
        if primary then
            inv.items[primary].count = balance
            inv.items[primary].weight = 0
            changed[#changed + 1] = primary
        else
            local target = inv:firstFree()
            if target then
                inv:addItem('money', balance, {})
                changed[#changed + 1] = target
            end
        end
    elseif primary then
        inv:removeFromSlot(primary, inv.items[primary].count)
        changed[#changed + 1] = primary
    end

    inv:recalcWeight()
    return changed
end

function Money.get(source)
    local fw = Framework.getMoney(source, 'cash')
    if fw ~= nil then return fw end
    local inv = Inventory.get(source)
    return inv and countItem(inv, 'money') or 0
end

function Money.canAfford(source, amount)
    return Money.get(source) >= amount
end

--- Charge the player. Returns ok plus the slot ids that changed (to refresh).
--- @return boolean ok
--- @return integer[] changed
function Money.charge(source, amount)
    local inv = Inventory.get(source)
    if not inv then return false, {} end

    if Money.useFramework(source) then
        if not Framework.removeMoney(source, 'cash', amount) then return false, {} end
        return true, Money.syncItem(source)
    end

    if countItem(inv, 'money') < amount then return false, {} end

    local changed = {}
    for slotId, slot in pairs(inv.items) do
        if amount <= 0 then break end
        if slot.name == 'money' then
            local take = math.min(slot.count, amount)
            inv:removeFromSlot(slotId, take)
            amount = amount - take
            changed[#changed + 1] = slotId
        end
    end
    return true, changed
end

--- Account-aware affordability. `account` may be 'cash' or 'bank'. Bank only
--- works with a framework; standalone always uses the cash/money item.
function Money.afford(source, amount, account)
    account = account or 'cash'
    if account == 'bank' then
        local bank = Framework.getMoney(source, 'bank')
        return bank ~= nil and bank >= amount
    end
    return Money.canAfford(source, amount)
end

--- Account-aware charge. Returns ok plus changed slot ids (only the cash item
--- ever changes the inventory display).
--- @return boolean ok
--- @return integer[] changed
function Money.chargeAccount(source, amount, account)
    account = account or 'cash'
    if account == 'bank' then
        if Framework.getMoney(source, 'bank') == nil then return false, {} end
        if not Framework.removeMoney(source, 'bank', amount) then return false, {} end
        return true, {}
    end
    return Money.charge(source, amount)
end

--- Give money back (used when a charged purchase couldn't be delivered).
function Money.refund(source, amount, account)
    account = account or 'cash'
    if account == 'bank' or Money.useFramework(source) then
        Framework.addMoney(source, account, amount)
        Money.syncItem(source)
        return
    end
    local inv = Inventory.get(source)
    if inv then inv:addItem('money', amount, {}) end
end

return Money
