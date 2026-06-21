--- Stash definitions. Each stash is a persistent shared container.
---
---   id     unique key (also the database owner_id)
---   label  header shown in the UI
---   slots  number of slots
---   weight max weight in grams
---   coords optional vector3 — when set, a "press E to open" point is created
---   groups optional table<string, number> of job/grade requirements (future)
return {
    {
        id = 'townstash',
        label = 'Town Storage',
        slots = 50,
        weight = 100000,
        coords = vec3(25.7, -1347.3, 29.49),
    },
    {
        id = 'garage_a',
        label = 'Garage A',
        slots = 30,
        weight = 80000,
        coords = vec3(-337.5, -136.8, 39.0),
    },
    {
        -- PIN-locked stash: the existing PIN overlay appears on open.
        id = 'vault',
        label = 'Secure Vault',
        slots = 40,
        weight = 200000,
        coords = vec3(253.1, 222.0, 106.3),
        pin = '1234',
    },
}
