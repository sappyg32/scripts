local plants = {}          -- [locationIndex][plantIndex] = { entity, available }
local labProps = {}
local distributor = nil

---------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------
local function loadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

local function groundZ(x, y, fallback)
    -- walkable-ground sample: probe from high above so slopes and
    -- out-of-stream terrain resolve, and fall back to collision loading
    local found, z = GetGroundZFor_3dCoord(x, y, 1000.0, false)
    if found then return z end

    RequestCollisionAtCoord(x, y, fallback + 5.0)
    local timeout = GetGameTimer() + 1500
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < timeout do
        Wait(0)
    end

    local ok, z2 = GetGroundZFor_3dCoord(x, y, fallback + 100.0, false)
    if ok then return z2 end

    return fallback
end

-- Build the spawn ring up front by sampling walkable ground around the
-- centre. Doing this as a pass (rather than per-plant at spawn time) means
-- every plant lands on terrain that is already resolved and streamed in,
-- which is what stops them clipping through the map.
local function buildSpawnPoints(loc)
    local points = {}

    for i = 1, loc.plantCount do
        local angle = (i / loc.plantCount) * math.pi * 2 + math.random() * 0.4
        local dist  = math.sqrt(math.random()) * loc.radius
        local x     = loc.marker.x + math.cos(angle) * dist
        local y     = loc.marker.y + math.sin(angle) * dist

        local z = groundZ(x, y, loc.marker.z)

        if math.abs(z - loc.marker.z) > 0.2 then
            -- corroborate with a second probe to reject stray hits
            local _, z2 = GetGroundZFor_3dCoord(x, y, 1000.0, false)
            if z2 then z = z2 end
        end

        points[i] = vector3(x, y, z)
    end

    return points
end

local function placePlant(locIndex, plantIndex)
    local loc = Config.Harvest[locIndex]
    local coords = loc.spawnPoints[plantIndex] or randomGroundCoords(loc.marker, loc.radius)

    local entity = CreateObjectNoOffset(
        joaat(loc.prop),
        coords.x, coords.y, coords.z,
        false, false, false
    )

    if entity == 0 then return nil end

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityRotation(entity, 0.0, 0.0, math.random(0, 359) + 0.0, 2, true)

    -- single snap, then freeze: the object gets two frames to exist first so
    -- the snap actually resolves instead of no-oping
    Wait(0)
    PlaceObjectOnGroundProperly(entity)
    Wait(0)
    PlaceObjectOnGroundProperly(entity)

    FreezeEntityPosition(entity, true)

    local state = { entity = entity, available = true }

    -- ox_target on the plant
    exports.ox_target:addLocalEntity(entity, {
        {
            name     = ('harvest_%s_%d'):format(loc.name, plantIndex),
            label    = ('Harvest %s'):format(loc.label),
            icon     = 'fa-solid fa-seedling',
            distance = 1.5,
            canInteract = function() return state.available end,
            onSelect = function()
                harvestPlant(locIndex, plantIndex)
            end
        }
    })

    return state
end

---------------------------------------------------------------------
-- Harvesting
---------------------------------------------------------------------
function harvestPlant(locIndex, plantIndex)
    local loc   = Config.Harvest[locIndex]
    local state = plants[locIndex] and plants[locIndex][plantIndex]
    if not state or not state.available then return end

    -- server-validated give
    local ok = lib.callback.await('harvest:giveItem', false, loc.item, loc.amount)
    if not ok then
        lib.notify({ type = 'error', description = 'Your hands are full.' })
        return
    end

    state.available = false

    if DoesEntityExist(state.entity) then
        SetEntityAsMissionEntity(state.entity, true, true)
        DeleteEntity(state.entity)
    end

    -- respawn timer
    SetTimeout(loc.respawn * 1000, function()
        local new = placePlant(locIndex, plantIndex)
        plants[locIndex][plantIndex] = new
    end)
end

---------------------------------------------------------------------
-- Build harvest sites
---------------------------------------------------------------------
CreateThread(function()
    for i, loc in ipairs(Config.Harvest) do
        plants[i] = {}

        -- blip
        local blip = AddBlipForCoord(loc.marker.x, loc.marker.y, loc.marker.z)
        SetBlipSprite(blip, loc.blip.sprite)
        SetBlipColour(blip, loc.blip.color)
        SetBlipScale(blip, loc.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(loc.blip.label)
        EndTextCommandSetBlipName(blip)

        if loadModel(loc.prop) then
            -- resolve every spawn point's ground height before placing any
            -- prop, so nothing is created against unresolved terrain
            RequestCollisionAtCoord(loc.marker.x, loc.marker.y, loc.marker.z + 2.0)

            local waitUntil = GetGameTimer() + 3000
            while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < waitUntil do
                Wait(10)
            end

            loc.spawnPoints = buildSpawnPoints(loc)

            for p = 1, loc.plantCount do
                plants[i][p] = placePlant(i, p)
                Wait(10)
            end
        end
    end
end)

---------------------------------------------------------------------
-- The Lab
---------------------------------------------------------------------
CreateThread(function()
    local lab = Config.Lab

    local blip = AddBlipForCoord(lab.marker.x, lab.marker.y, lab.marker.z)
    SetBlipSprite(blip, lab.blip.sprite)
    SetBlipColour(blip, lab.blip.color)
    SetBlipScale(blip, lab.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(lab.blip.label)
    EndTextCommandSetBlipName(blip)

    local options = {}
    for _, recipe in ipairs(lab.recipes) do
        options[#options + 1] = {
            name     = 'lab_' .. recipe.label:gsub('%s+', '_'):lower(),
            label    = recipe.label,
            icon     = recipe.icon,
            distance = 2.5,
            onSelect = function()
                local ok = lib.callback.await('harvest:process', false,
                    recipe.cost.item, recipe.cost.amount,
                    recipe.reward.item, recipe.reward.amount)
                if ok then
                    lib.notify({ type = 'success',
                        description = ('Received %dx %s'):format(recipe.reward.amount, recipe.reward.item) })
                else
                    lib.notify({ type = 'error', description = 'You lack the required ingredients.' })
                end
            end
        }
    end

    -- world-position target: no prop, just a zone you can interact with
    exports.ox_target:addSphereZone({
        coords  = vector3(lab.marker.x, lab.marker.y, lab.marker.z),
        radius  = 2.0,
        debug   = false,
        options = options
    })
end)

---------------------------------------------------------------------
-- Distributor NPC
---------------------------------------------------------------------
CreateThread(function()
    local dist = Config.Distributor

    local blip = AddBlipForCoord(dist.marker.x, dist.marker.y, dist.marker.z)
    SetBlipSprite(blip, dist.blip.sprite)
    SetBlipColour(blip, dist.blip.color)
    SetBlipScale(blip, dist.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(dist.blip.label)
    EndTextCommandSetBlipName(blip)

    if not loadModel(dist.model) then return end

    distributor = CreatePed(4, joaat(dist.model),
        dist.marker.x, dist.marker.y, dist.marker.z - 1.0,
        dist.marker.w, false, true)

    SetEntityAsMissionEntity(distributor, true, true)
    SetPedFleeAttributes(distributor, 0, false)
    SetBlockingOfNonTemporaryEvents(distributor, true)
    SetPedCanRagdoll(distributor, false)
    SetEntityInvincible(distributor, true)

    -- 10 ft wander around spawn
    TaskWanderInArea(distributor,
        dist.marker.x, dist.marker.y, dist.marker.z,
        dist.wanderRadius, 1.0, 3.0)

    local options = {}
    for _, offer in ipairs(dist.offers) do
        options[#options + 1] = {
            name     = 'dist_' .. offer.item,
            label    = offer.label,
            icon     = offer.icon,
            distance = 2.5,
            onSelect = function()
                local ok = lib.callback.await('harvest:sell', false,
                    offer.item, offer.amount, offer.payout)
                if ok then
                    lib.notify({ type = 'success',
                        description = ('Sold %dx %s for $%d'):format(offer.amount, offer.item, offer.payout) })
                else
                    lib.notify({ type = 'error', description = 'You have nothing to sell.' })
                end
            end
        }
    end

    exports.ox_target:addLocalEntity(distributor, options)
end)
