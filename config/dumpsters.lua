--- Searchable world containers (dumpsters). Walk up to one of these props and
--- press the key to rummage for random loot. Each dumpster can be searched
--- again after `cooldown` ms.
return {
    key      = 38,        -- INPUT_PICKUP (E)
    distance = 1.8,
    slots    = 8,
    weight   = 30000,
    cooldown = 10 * 60 * 1000, -- 10 minutes before it can refill

    models = {
        'prop_dumpster_01a',
        'prop_dumpster_02a',
        'prop_dumpster_02b',
        'prop_dumpster_3a',
        'prop_dumpster_4a',
        'prop_dumpster_4b',
    },

    -- Each entry: chance (0..1) to appear, and the amount range when it does.
    loot = {
        { name = 'water',      chance = 0.40, min = 1, max = 2 },
        { name = 'burger',     chance = 0.30, min = 1, max = 1 },
        { name = 'scrapmetal', chance = 0.55, min = 1, max = 4 },
        { name = 'bandage',    chance = 0.20, min = 1, max = 1 },
        { name = 'money',      chance = 0.15, min = 1, max = 40 },
        { name = 'lockpick',   chance = 0.10, min = 1, max = 1 },
    },
}
