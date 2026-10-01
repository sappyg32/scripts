Config = {}

-- Harvest locations
Config.Harvest = {
    {
        name        = 'grain_field',
        label       = 'Grain Field',
        marker      = vec4(-2180.98, 2484.92, 5.09, 330.17),
        prop        = 'prop_veg_crop_03_cab',    -- grain-ish prop; swap for your own
        item        = 'magic_grain',
        amount      = 3,
        respawn     = 60,                        -- seconds
        plantCount  = 20,
        radius      = 20.0,                      -- spread of the plants
        blip        = { sprite = 1, color = 5, scale = 0.8, label = 'Grain Field' }
    },
    {
        name        = 'coco_leaves',
        label       = 'Coco Leaves',
        marker      = vec4(220.86, 7402.41, 16.91, 330.17),
        prop        = 'h4_prop_bush_cocaplant_01',
        useAutoSnap = false,                     -- this bush's origin misreports
        zAdjust     = 0.6,                       -- lift out of the terrain
        item        = 'coco_leaf',
        amount      = 2,
        respawn     = 120,                       -- seconds
        plantCount  = 20,
        radius      = 20.0,
        blip        = { sprite = 1, color = 2, scale = 0.8, label = 'Coco Leaves' }
    }
}

-- Processing lab
Config.Lab = {
    marker = vec4(3560.14, 3674.92, 28.12, 167.75),
    model  = 'prop_table_04',
    blip   = { sprite = 499, color = 27, scale = 0.9, label = 'The Lab' },
    recipes = {
        {
            label    = 'Process Magic Grain',
            icon     = 'fa-solid fa-flask',
            cost     = { item = 'magic_grain', amount = 1 },
            reward   = { item = 'acid', amount = 10 }
        },
        {
            label    = 'Process Coco',
            icon     = 'fa-solid fa-mortar-pestle',
            cost     = { item = 'coco_leaf', amount = 1 },
            reward   = { item = 'yayo', amount = 3 }
        }
    }
}

-- Distributor NPC
Config.Distributor = {
    marker       = vec4(-242.14, 6257.20, 31.49, 240.15),
    model        = 'g_m_m_chigoon_02',
    wanderRadius = 3.05,        -- ~10 ft
    blip         = { sprite = 1, color = 1, scale = 0.9, label = 'Distributor' },
    offers = {
        { label = 'Sell Yayo', icon = 'fa-solid fa-sack-dollar', item = 'yayo', amount = 1, payout = 1000 },
        { label = 'Sell Acid', icon = 'fa-solid fa-sack-dollar', item = 'acid', amount = 1, payout = 500  }
    }
}
