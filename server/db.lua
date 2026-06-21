local Utils = require 'shared.utils'

--- Persistence layer. Uses its own table/schema (independent of any other
--- inventory resource): a single row per (owner, type) holding the slot list
--- as JSON.
local Db = {}

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `lk_inventories` (
    `owner_id`   VARCHAR(80)  NOT NULL,
    `inv_type`   VARCHAR(40)  NOT NULL DEFAULT 'player',
    `slots_json` LONGTEXT     NULL,
    `last_saved` TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`owner_id`, `inv_type`)
)
]]

local SNAPSHOT_SCHEMA = [[
CREATE TABLE IF NOT EXISTS `lk_snapshots` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `owner_id`   VARCHAR(80)  NOT NULL,
    `taken_at`   TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP,
    `slots_json` LONGTEXT     NULL,
    PRIMARY KEY (`id`),
    KEY `owner_id` (`owner_id`)
)
]]

function Db.init()
    MySQL.query(SCHEMA, {}, function()
        Utils.log('info', 'database ready (table lk_inventories)')
    end)
    MySQL.query(SNAPSHOT_SCHEMA)
end

--- Save a snapshot and prune to the newest `keep` for this owner.
function Db.saveSnapshot(ownerId, slotsJson, keep)
    MySQL.insert('INSERT INTO lk_snapshots (owner_id, slots_json) VALUES (?, ?)',
        { ownerId, slotsJson }, function()
            MySQL.query([[
                DELETE FROM lk_snapshots WHERE owner_id = ? AND id NOT IN (
                    SELECT id FROM (
                        SELECT id FROM lk_snapshots WHERE owner_id = ? ORDER BY id DESC LIMIT ?
                    ) keep_set
                )]], { ownerId, ownerId, keep or 6 })
        end)
end

--- @return table[] rows  newest-first { taken_at, slots_json }
function Db.loadSnapshots(ownerId, limit)
    return MySQL.query.await(
        'SELECT taken_at, slots_json FROM lk_snapshots WHERE owner_id = ? ORDER BY id DESC LIMIT ?',
        { ownerId, limit or 6 }) or {}
end

--- @param ownerId string
--- @param invType string?
--- @return table slots  array of stored slots (empty when none)
function Db.load(ownerId, invType)
    local stored = MySQL.scalar.await(
        'SELECT slots_json FROM lk_inventories WHERE owner_id = ? AND inv_type = ?',
        { ownerId, invType or 'player' }
    )

    if not stored then return {} end

    local ok, decoded = pcall(json.decode, stored)
    return (ok and type(decoded) == 'table') and decoded or {}
end

--- @param ownerId string
--- @param invType string?
--- @param slots table  array of slots to persist
function Db.save(ownerId, invType, slots)
    MySQL.prepare(
        [[INSERT INTO lk_inventories (owner_id, inv_type, slots_json)
          VALUES (?, ?, ?)
          ON DUPLICATE KEY UPDATE slots_json = VALUES(slots_json)]],
        { ownerId, invType or 'player', json.encode(slots or {}) }
    )
end

--- @param ownerId string
--- @param invType string?
function Db.delete(ownerId, invType)
    MySQL.prepare('DELETE FROM lk_inventories WHERE owner_id = ? AND inv_type = ?',
        { ownerId, invType or 'player' })
end

--- @return boolean exists
function Db.exists(ownerId, invType)
    return MySQL.scalar.await(
        'SELECT 1 FROM lk_inventories WHERE owner_id = ? AND inv_type = ?',
        { ownerId, invType or 'player' }) ~= nil
end

return Db
