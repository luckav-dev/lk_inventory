local Config = require 'config.config'

local Utils = {}

--- Leveled logging controlled by Config.logLevel.
local levels = { error = 0, info = 1, debug = 2 }

function Utils.log(level, ...)
    if (levels[level] or 0) > Config.logLevel then return end
    local tag = ('[lk_inv:%s]'):format(level)
    print(tag, ...)
end

--- Recursive table clone (values only, no metatables).
function Utils.clone(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = Utils.clone(v)
    end
    return copy
end

--- Count populated entries of a (possibly sparse) table.
function Utils.count(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

--- Round to a whole number, never negative.
function Utils.posInt(n)
    n = math.floor(tonumber(n) or 0)
    return n > 0 and n or 0
end

return Utils
