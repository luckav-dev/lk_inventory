local Config = require 'config.config'

--- Lightweight metrics: counters incremented across the inventory, exposed as a
--- console summary (/lk_stats) and a Prometheus /metrics HTTP endpoint.
local Metrics = {}

local counters = {}
local startedAt = os.time()

local HELP = {
    items_added    = 'Items added',
    items_removed  = 'Items removed',
    swaps          = 'Item moves/swaps',
    drops_created  = 'Ground drops created',
    buys           = 'Shop purchases',
    crafts         = 'Crafts completed',
    throws         = 'Items thrown',
    frisks         = 'Player searches',
    dumpsters      = 'Dumpster searches',
    money_given    = 'Cash transfers',
    dupes_flagged  = 'Duplication flags',
    rollbacks      = 'Inventory rollbacks',
    exploit_flags  = 'Security flags',
}

function Metrics.inc(name, by)
    if not Config.metrics.enabled then return end
    counters[name] = (counters[name] or 0) + (by or 1)
end

function Metrics.snapshot()
    return counters
end

--- Prometheus text exposition.
local function prometheus()
    local lines = {
        '# lk_inv metrics',
        ('lk_inv_uptime_seconds %d'):format(os.time() - startedAt),
    }
    for name, help in pairs(HELP) do
        local metric = ('lk_inv_%s'):format(name)
        lines[#lines + 1] = ('# HELP %s %s'):format(metric, help)
        lines[#lines + 1] = ('# TYPE %s counter'):format(metric)
        lines[#lines + 1] = ('%s %d'):format(metric, counters[name] or 0)
    end
    return table.concat(lines, '\n') .. '\n'
end

CreateThread(function()
    if not (Config.metrics.enabled and Config.metrics.http) then return end
    SetHttpHandler(function(req, res)
        if req.path == '/metrics' then
            res.writeHead(200, { ['Content-Type'] = 'text/plain; version=0.0.4' })
            res.send(prometheus())
        else
            res.writeHead(404)
            res.send('lk_inv: try /metrics')
        end
    end)
end)

RegisterCommand('lk_stats', function(source)
    if source ~= 0 then return end -- console only
    print('^5[lk_inv] metrics summary:^0')
    print(('  uptime: %ds'):format(os.time() - startedAt))
    for name in pairs(HELP) do
        print(('  %-14s %d'):format(name, counters[name] or 0))
    end
end, true)

return Metrics
