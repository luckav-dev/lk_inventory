--- Crafting bench definitions.
---
---   id      unique key
---   label   header shown in the UI
---   coords  optional vector3 — when set, a "press E to craft" point is made
---   recipes list of:
---             name        result item
---             count       result amount (default 1)
---             duration    craft time in ms (default 3000)
---             ingredients table<itemName, amount> consumed on craft
return {
    {
        id = 'workbench',
        label = 'Workbench',
        coords = vec3(-321.1, -135.2, 39.0),
        recipes = {
            {
                name = 'bandage', count = 1, duration = 4000,
                ingredients = { scrapmetal = 2, water = 1 },
            },
            {
                -- 70% success: a failed craft still consumes the materials.
                name = 'lockpick', count = 1, duration = 6000,
                successChance = 0.7,
                ingredients = { scrapmetal = 3 },
            },
            {
                name = 'ammo_9', count = 30, duration = 8000,
                ingredients = { scrapmetal = 5 },
            },
        },
    },
}
