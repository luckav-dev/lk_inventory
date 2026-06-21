--- Central settings for the LK inventory.
return {
    -- Interface language: matches a file in locales/ (en | es | pt | ...).
    locale = 'en',

    -- Default player capacity
    playerSlots  = 50,
    playerWeight = 50000, -- grams (50 kg)

    -- Ground drops
    drops = {
        -- Spawn a real, visible world object for every drop instead of a
        -- generic bag. Weapons show their own weapon model, items use the
        -- model configured per item (or the fallback below).
        spawnProps    = true,
        fallbackModel = 'prop_cs_cardbox_01',
        pickupKey     = 38,    -- INPUT_PICKUP (E)
        kickKey       = 47,    -- INPUT_DETONATE (G) — kick/push a ground drop
        kickForce     = 7.0,
        interactDist  = 1.6,
        renderDist    = 20.0,
        despawnAfter  = 15 * 60 * 1000, -- 15 min of nobody nearby (0 = never)
        maxWeight     = 100000,
        maxPerPlayer  = 12,    -- anti-dump: active ground drops a player may own
        maxTotal      = 400,   -- anti-dump: total active ground drops on the server
    },

    -- Anti-exploit token-bucket limits (actions / window-ms).
    security = {
        swap = { rate = 25, per = 1000 },
        drop = { rate = 6,  per = 2000 },
        use  = { rate = 12, per = 1000 },
    },

    -- Open/close behaviour
    open = {
        command   = 'inv',
        keybind   = 'TAB',
        screenBlur = true,
        useTarget  = false,
    },

    -- Vehicle storage (persisted per number plate). Trunk/glovebox size depends
    -- on the vehicle: a truck carries far more than a car, a van more than a
    -- car, a motorcycle less, a 4x4 differs from a sports car, etc.
    vehicles = {
        key       = 'H',   -- opens glovebox when seated, else nearest trunk
        trunkDist = 4.0,   -- how close (on foot) to open a trunk

        -- Fallback for any class not listed below (sedans, SUVs, coupes...).
        default = {
            trunk = { slots = 40, weight = 120000 },
            glove = { slots = 8,  weight = 15000 },
        },

        -- Capacity by GetVehicleClass id.
        classSpace = {
            [8]  = { trunk = { slots = 5,   weight = 8000 },   glove = { slots = 3,  weight = 4000 } },  -- Motorcycles
            [13] = { trunk = { slots = 2,   weight = 3000 },   glove = { slots = 1,  weight = 1500 } },  -- Cycles
            [6]  = { trunk = { slots = 25,  weight = 70000 },  glove = { slots = 8,  weight = 12000 } }, -- Sports
            [7]  = { trunk = { slots = 18,  weight = 50000 },  glove = { slots = 6,  weight = 10000 } }, -- Super
            [4]  = { trunk = { slots = 30,  weight = 90000 },  glove = { slots = 8,  weight = 14000 } }, -- Muscle
            [9]  = { trunk = { slots = 55,  weight = 180000 }, glove = { slots = 10, weight = 20000 } }, -- Off-road (4x4)
            [2]  = { trunk = { slots = 50,  weight = 160000 }, glove = { slots = 10, weight = 20000 } }, -- SUVs
            [12] = { trunk = { slots = 75,  weight = 260000 }, glove = { slots = 10, weight = 22000 } }, -- Vans
            [11] = { trunk = { slots = 85,  weight = 320000 }, glove = { slots = 12, weight = 24000 } }, -- Utility
            [10] = { trunk = { slots = 120, weight = 520000 }, glove = { slots = 12, weight = 26000 } }, -- Industrial (trucks)
            [20] = { trunk = { slots = 120, weight = 520000 }, glove = { slots = 12, weight = 26000 } }, -- Commercial (trucks)
        },

        -- Per-model overrides by spawn name (highest priority).
        modelSpace = {
            boxville  = { trunk = { slots = 95, weight = 380000 } },
            pounder   = { trunk = { slots = 140, weight = 650000 } },
            speedo    = { trunk = { slots = 70, weight = 240000 } },
        },
    },

    -- Stealth pickpocketing of a nearby player (one item, fail alerts them).
    pickpocket = {
        chance = 0.55,
    },

    -- Surprising realism: cargo weight in the trunk affects vehicle performance.
    cargo = {
        enabled    = true,
        maxPenalty = 0.40, -- up to -40% engine torque at a full trunk
    },

    -- Throw an item by hand (grenade/snowball-style): the item shows in your
    -- hand, you play a throwing animation, and it flies and lands as a real
    -- ground object. Animation dict/clip are tunable per server.
    throw = {
        enabled = true,
        anim    = { dict = 'weapons@projectile@', clip = 'throw_m_fb_stand', release = 650 },
        force   = 15.0, -- horizontal throw speed
        upForce = 4.5,  -- vertical arc
        settle  = 1300, -- ms to wait for it to land before creating the drop
    },

    -- Visible equipment on the body: holstered weapons and a worn backpack.
    -- Bone ids and offsets are approximate — tune per server.
    visuals = {
        enabled = true,
        bag = {
            prop = 'prop_cs_heist_bag_strap_01',
            bone = 24818, -- SKEL_Spine3 (back)
            pos  = vec3(0.10, -0.19, 0.0),
            rot  = vec3(0.0, 0.0, 0.0),
        },
        slots = {
            back  = { bone = 24818, pos = vec3(-0.05, -0.17, 0.0), rot = vec3(0.0, 180.0, -120.0) },
            thigh = { bone = 51826, pos = vec3(0.10, 0.0, -0.02),  rot = vec3(180.0, 90.0, 0.0) },
        },
    },

    -- Notifications. 'auto' uses ox_lib's lib.notify when ox_lib is running,
    -- otherwise our own themed NUI notifications built into the inventory (never
    -- the native GTA feed). 'oxlib'/'interface' force one; 'custom' forwards
    -- every notification to the `lk_inv:notification` event so the server can
    -- route it to its own system (no collision with other notification scripts).
    notify = {
        provider = 'auto', -- auto | oxlib | interface | custom
        position = 'top-right',
    },

    -- Inventory action logging. Fires the `lk_inv:log` event for external
    -- loggers and (optionally) posts to a Discord webhook.
    logs = {
        enabled = true,
        console = true,
        webhook = '', -- Discord webhook URL ('' to disable)
        -- per-category toggles
        categories = {
            drop = true, give = true, buy = true, craft = true,
            frisk = true, dumpster = true, money = true, stash = true,
        },
    },

    -- Compatibility layer: expose ox_inventory-style exports so the existing
    -- script ecosystem (jobs, shops, drugs...) works unchanged. Auto-disabled
    -- when a real ox_inventory resource is present, so there's no collision.
    compat = {
        oxinventory = true,
    },

    -- Admin gating for the audit panel and rollback commands (ACE permission).
    admin = { ace = 'lk_inv.admin' },

    -- Duplication detection: scans loaded inventories for the same unique item
    -- instance existing in two places and (optionally) removes the copy.
    dupe = {
        enabled    = true,
        interval   = 60 * 1000,
        autoRemove = false, -- log/flag only by default; enable to delete copies
    },

    -- Periodic inventory snapshots for anti-dupe rollback.
    snapshots = {
        enabled  = true,
        keep     = 6,            -- snapshots retained per player
        interval = 5 * 60 * 1000,
    },

    -- Metrics: console summary (/lk_stats) and a Prometheus /metrics endpoint
    -- served on the resource's HTTP handler.
    metrics = {
        enabled = true,
        http    = true,
    },

    -- In-memory audit log size (entries kept for the audit panel).
    auditBuffer = 200,

    -- How often (ms) dirty inventories are flushed to the database
    saveInterval = 5 * 60 * 1000,

    -- Logging verbosity: 0 = errors only, 1 = info, 2 = debug
    logLevel = 1,
}
