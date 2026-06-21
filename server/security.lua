local Config = require 'config.config'
local Utils  = require 'shared.utils'

--- Lightweight anti-exploit layer: token-bucket rate limiting per player/action
--- to stop dump/dupe spam, plus a flag hook other anti-cheats can listen to.
local Security = {}

-- source -> action -> { tokens, last }
local buckets = {}

--- @return boolean allowed
function Security.allow(source, action)
    local lim = Config.security[action]
    if not lim then return true end

    local now = GetGameTimer()
    buckets[source] = buckets[source] or {}
    local b = buckets[source][action]

    if not b then
        b = { tokens = lim.rate, last = now }
        buckets[source][action] = b
    end

    -- Refill proportionally to elapsed time.
    local elapsed = now - b.last
    b.tokens = math.min(lim.rate, b.tokens + (elapsed / lim.per) * lim.rate)
    b.last = now

    if b.tokens >= 1 then
        b.tokens = b.tokens - 1
        return true
    end
    return false
end

--- Record a suspicious action; external anti-cheats can hook `lk_inv:exploit`.
function Security.flag(source, reason)
    Utils.log('error', ('player %s flagged: %s'):format(source, reason))
    TriggerEvent('lk_inv:exploit', source, reason)
end

function Security.clear(source)
    buckets[source] = nil
end

return Security
