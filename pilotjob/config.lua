Config = {}

Config.StartZone = {
    coords = vector4(-954.99, -2764.40, 13.94, 281.67),
    markerRadius = 1.5,      -- press-E radius (metres)
    markerRange  = 40.0,     -- distance the ground marker draws at (metres)
    blipRange    = 100.0,    -- distance the blip also appears on the minimap (metres)
    mapBlip = {
        sprite = 307,          -- plane blip
        color  = 1,
        scale  = 0.9,
        label  = 'Pilot Job'
    }
}

Config.JetSpawn = vector4(-1665.49, -2784.07, 13.94, 334.30)
Config.JetModel = 'luxor'

Config.DropZone = {
    coords        = vector4(1563.02, 3217.38, 40.41, 287.00),
    markerRadius  = 3.0,
    requiredDist  = 30.48,   -- 100 feet
    mapBlip = {
        sprite = 311,          -- passenger/flag style blip
        color  = 1,
        scale  = 1.0,
        label  = 'Passenger Drop-off'
    }
}

Config.Payout      = 10000
Config.DespawnWait = 10   -- seconds after passengers exit
Config.DrawDist    = 140  -- feet; distance to render markers/blips

-- HUD backend: 'auto' tries exports, then events, then falls back to a
-- native GTA text render so an objective always shows something.
Config.Hud = {
    mode       = 'auto',   -- 'auto' | 'export' | 'event' | 'native' | 'off'
    exportName = 'esx_hud',
    exportFn   = 'setObjective',
    eventName  = 'esx_hud:setObjective'
}
