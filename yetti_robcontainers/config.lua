Config = {}

Config.Debug = false

Config.Dispatch = 'none' -- Dispatch - 'cd' / 'ps' / 'none'
Config.PoliceJobs = {'police', 'lssd', 'sheriff', 'sahp'} -- Jobs that see the dispatch, if using cd dispatch, if ps then in ps dispatch config
Config.DispatchCode = '10-17' -- Code on the dispatch
Config.DispatchMessage = 'Suspicius person exiting container'

Config.RequiredItem = 'lockpick'

Config.ContainerCoords = {
    [1] = vector3(910.5751, -3039.4622, 5.9020),
    [2] = vector3(1005.7899, -3095.9290, 5.9010),
    [3] = vector3(1149.8953, -2987.3542, 5.9010),
    [4] = vector3(845.1858, -3085.2563, 5.9008),
    [5] = vector3(1048.6450, -2992.2795, 5.9010),

    -- Add more if you want
    -- [6] = vector3(1234, 1234, 124),
}

-- ==========================================================
--  GANG NPC  (request point)
-- ==========================================================
Config.Npc = {
    coords = vec4(336.45, -1015.20, 29.29, 100.44), -- heading 100.44
    model  = `s_m_y_dealer_01`,                     -- swap for your gang ped
    label  = 'Request Container Jobs',
    icon   = 'fa-solid fa-user-secret',
    blip = {
        sprite = 480,     -- gang / dealer style sprite
        colour = 1,       -- red
        scale  = 0.85,
        label  = 'Container Jobs',
    },
}

-- Containers only appear (blips) after requesting from the NPC
Config.UseNpcRequest = true

Config.ContainerBlip = {
    sprite  = 478,   -- crate / container sprite
    colour  = 5,     -- yellow
    scale   = 0.8,
    label   = 'Rob Container',
    shortRange = false, -- false = visible across the whole map
}

Config.RequestCooldown = 600 -- 10 minutes, in seconds

-- ==========================================================
--  REWARDS  -- every container pays 5000 black money
-- ==========================================================
Config.DirtyMoneyItem = 'black_money' -- item name in your inventory
Config.ContainerPayout = 5000

-- If your server gives black money as a stackable item with a metadata
-- value, set this and server.lua will pass metadata instead of a count.
Config.MarkedBillsMetadata = false -- true = pass metadata { worth = ... }
Config.MarkedBillsWorth = 1        -- value per bill when metadata is on

Config.Reward = { -- Rewards to pick randomly from
    { item = Config.DirtyMoneyItem, chance = 100, amount = Config.ContainerPayout },
    -- { item = 'weapon_pistol', chance = 50, amount = math.random(3,5) },
}

Config.Cooldown = 120 -- In seconds (per-container re-entry lock)

Config.TargetLabelBreak = 'Break Into Container' -- Label on target to break into
Config.TargetIconBreak = 'fa-solid fa-hammer' -- Icon on target to break into - https://fontawesome.com/icons

Config.TargetLabelExit = 'Exit' -- Label on target to exit
Config.TargetIconExit = 'fa-solid fa-door-open' -- Icon on target to exit - https://fontawesome.com/icons

Config.TargetLabelBox = 'Loot Box' -- Label on target to take loot from box
Config.TargetIconBox = 'fa-solid fa-box' -- Icon on target to take loot from box - https://fontawesome.com/icons

Config.TargetDistance = 2

Config.NotifyTitle = 'Required Items'
Config.NotifyDescription = 'You don\'t have the required item to break into the container'

Config.FailTitle = 'Failed'
Config.FailDescription = 'You failed to lockpick the container'

Config.ProgressBarLabel = 'Opening Box'

Config.NoJobTitle = 'No Jobs'
Config.NoJobDescription = 'The gang has nothing for you right now'
Config.JobTitle = 'Container Jobs'
Config.JobDescription = 'Locations marked on your map'
Config.CompletedTitle = 'Jobs Done'
Config.CompletedDescription = 'Hand in completed - come back in 10 minutes'


-- Lock the config to make cheaters unable to edit code
function protect(tbl)
    return setmetatable({}, {
        __index = tbl,
        __newindex = function(t, k, v)
            error('Attempting to modify protected config', 2)
        end,
        __metatable = false,
    })
end

Config = protect(Config)
