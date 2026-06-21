--- Item registry. Each entry describes a single item.
---
--- Fields:
---   label       display name
---   weight      grams per unit
---   stack       can multiple units share a slot
---   close       close the inventory when used
---   usable      exposes a "Use" action (server use handler optional)
---   description tooltip text
---   image       custom image filename (defaults to "<name>.png")
---   ground      world model spawned when the item is dropped or thrown
---               (realism). Weapons use their own weapon object automatically.
---   hold        optional { pos = vec3, rot = vec3 } offset for how the prop
---               sits in the hand when thrown/carried/used (props have different
---               origins; tune per item). Defaults to a sensible value.
---   useAnim     optional { dict, clip, duration, prop?, noProp? } — animation
---               played when the item is used; the prop (or `ground`) shows in
---               the hand unless `noProp`. Anim names are tunable per server.
---   degrade     minutes until durability reaches 0 (optional)
---
--- Every item should define `ground` so it shows correctly in the hand and on
--- the floor. Items without one fall back to a generic box. Small starter set —
--- add your own freely.
return {
    water = {
        label = 'Water', weight = 500, stack = true, close = false, usable = true,
        description = 'A refreshing bottle of water.',
        ground = 'prop_ld_flow_bottle',
        hold = { pos = vec3(0.13, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
        effects = { thirst = 25 }, -- relayed to a status/metabolism resource
        -- Play a drinking animation with the bottle in hand when used.
        useAnim = { dict = 'mp_player_intdrink', clip = 'loop_bottle', duration = 3500 },
    },
    burger = {
        label = 'Burger', weight = 220, stack = true, close = false, usable = true,
        description = 'Greasy but it does the job.',
        ground = 'prop_cs_burger_01',
        effects = { hunger = 30 },
        useAnim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', duration = 3500 },
    },
    bandage = {
        label = 'Bandage', weight = 100, stack = true, close = false, usable = true,
        ground = 'prop_cs_tablet',
        effects = { health = 15 },
        -- No prop; just a brief patch-up gesture.
        useAnim = { dict = 'amb@world_human_clipboard@male@idle_a', clip = 'idle_c', duration = 3000, noProp = true },
    },
    -- Limited-use item (charges decrement per use).
    spray = {
        label = 'Spray Can', weight = 300, stack = false, close = false, usable = true,
        uses = 10, ground = 'prop_cs_spray_can',
    },
    -- Repair kit: restores the equipped weapon's durability.
    repairkit = {
        label = 'Weapon Repair Kit', weight = 800, stack = true, close = true, usable = true,
        repair = { amount = 100 }, ground = 'prop_tool_box_04',
    },
    phone = {
        label = 'Phone', weight = 190, stack = false, close = true, usable = true,
        ground = 'prop_npc_phone_02',
    },
    money = {
        label = 'Cash', weight = 0, stack = true, close = false, usable = false,
        ground = 'prop_cash_pile_01',
    },
    lockpick = {
        label = 'Lockpick', weight = 120, stack = true, close = true, usable = true,
        ground = 'prop_tool_screwdvr02',
    },
    scrapmetal = {
        label = 'Scrap Metal', weight = 280, stack = true, close = false, usable = false,
        ground = 'prop_rub_scrap_03',
    },

    -- Weapons: the ground model is resolved from the weapon hash automatically,
    -- so they appear as the actual gun lying on the floor.
    WEAPON_PISTOL = {
        label = 'Pistol', weight = 1200, stack = false, close = true, usable = true,
        weapon = true, ammoName = 'ammo_9', bodySlot = 'thigh',
    },
    WEAPON_KNIFE = {
        label = 'Knife', weight = 600, stack = false, close = true, usable = true,
        weapon = true, bodySlot = 'thigh',
    },
    ammo_9 = {
        label = '9mm Rounds', weight = 4, stack = true, close = false, usable = false,
        ammo = true, ground = 'prop_box_ammo04a',
    },

    -- Weapon attachments (used while a weapon is equipped to attach them).
    at_flashlight = {
        label = 'Weapon Flashlight', weight = 120, stack = true, close = true, usable = true,
        component = true, type = 'flashlight',
        client = { component = { 'COMPONENT_AT_PI_FLSH' } },
        ground = 'prop_cs_torch_01',
    },
    at_suppressor = {
        label = 'Suppressor', weight = 150, stack = true, close = true, usable = true,
        component = true, type = 'muzzle',
        client = { component = { 'COMPONENT_AT_PI_SUPP_02' } },
        ground = 'prop_box_ammo04a',
    },

    -- Container item: open it to access its own inventory (bag-in-bag).
    bag = {
        label = 'Backpack', weight = 1000, stack = false, close = true, usable = true,
        container = { slots = 20, weight = 40000 },
        ground = 'prop_cs_heist_bag_strap_01',
    },

    -- Carriable heavy item: pick it up in your hands, walk slowed, then set it
    -- down on the ground (it becomes a real world object).
    box = {
        label = 'Heavy Box', weight = 12000, stack = false, close = true, usable = true,
        ground = 'prop_box_guncase_01a',
        carry = {
            dict = 'anim@heists@box_carry@',
            anim = 'idle',
            prop = 'prop_box_guncase_01a',
            bone = 28422, -- PH_R_Hand
            pos  = vec3(0.05, 0.08, 0.20),
            rot  = vec3(0.0, 0.0, 0.0),
        },
    },
}
