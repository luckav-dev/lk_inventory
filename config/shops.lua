--- Shop definitions. Money is handled as the in-inventory `money` item (the UI
--- reads cash from it), so buying deducts `money` and adds the bought item.
---
---   id        unique key
---   label     header shown in the UI
---   coords    optional vector3 — when set, a "press E to shop" point is made
---   inventory list of { name, price, count? } entries on sale
return {
    {
        id = 'twentyfourseven',
        label = '24/7 Store',
        coords = vec3(25.0, -1347.3, 29.49),
        inventory = {
            { name = 'water',  price = 5 },
            { name = 'burger', price = 8 },
            { name = 'phone',  price = 250 },
        },
    },
    {
        id = 'ammunation',
        label = 'Ammu-Nation',
        coords = vec3(22.0, -1107.3, 29.8),
        inventory = {
            -- Firearms are bank-only (when a framework provides accounts).
            { name = 'WEAPON_PISTOL', price = 1500, currency = 'bank' },
            { name = 'ammo_9',        price = 2, count = 30 },
            { name = 'bandage',       price = 15 },
        },
    },
}
