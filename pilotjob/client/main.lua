local ESX = exports.es_extended:getSharedObject()

local jobActive   = false
local jet         = nil
local passengers  = {}
local startBlip   = nil
local dropBlip    = nil
local missionTs   = nil

local START_POS = Config.StartZone.coords
local DROP_POS  = Config.DropZone.coords

local DROP_XYZ = vec3(DROP_POS.x, DROP_POS.y, DROP_POS.z)

---------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------
-- Three backends so this works on any esx_hud fork:
--   export  -> exports.esx_hud:setObjective(bool, text)
--   event   -> TriggerEvent('esx_hud:setObjective', text)
--   native  -> our own DrawText, always works, zero dependencies
---------------------------------------------------------------------

local hudText    = nil
local hudNative  = false
local hudBackend = nil   -- resolved on first use

local function hudExportReady()
    local name = Config.Hud.exportName
    if not name then return false end
    if GetResourceState(name) ~= 'started' then return false end
    local ok = pcall(function()
        return exports[name][Config.Hud.exportFn]
    end)
    return ok
end

local function resolveHud()
    local m = Config.Hud and Config.Hud.mode or 'auto'
    if m == 'off' then return 'off' end

    if m == 'auto' or m == 'export' then
        if hudExportReady() then
            local ok = pcall(function()
                exports[Config.Hud.exportName][Config.Hud.exportFn](
                    Config.Hud.exportName, false, '')
            end)
            if ok then return 'export' end
        end
        if m == 'export' then return 'native' end
    end

    if m == 'auto' or m == 'event' then
        local ok = pcall(function()
            TriggerEvent(Config.Hud.eventName)
        end)
        if ok then return 'event' end
    end

    return 'native'
end

-- native fallback renderer, driven by hudText
CreateThread(function()
    while true do
        local sleep = 500
        if hudNative and hudText then
            sleep = 0
            SetTextFont(4)
            SetTextScale(0.0, 0.36)
            SetTextColour(255, 255, 255, 235)
            SetTextOutline()
            SetTextCentre(false)
            SetTextEntry('STRING')
            AddTextComponentSubstringPlayerName(hudText)
            DrawText(0.015, 0.520)
        end
        Wait(sleep)
    end
end)

local function setHud(text)
    hudText = text

    if hudBackend == nil then
        hudBackend = resolveHud()
        if hudBackend == 'native' then
            hudNative = true
        elseif hudBackend ~= 'off' then
            print(('[pilotjob] objective HUD using %s backend'):format(hudBackend))
        end
    end

    if hudText and hudBackend == 'export' then
        pcall(function()
            exports[Config.Hud.exportName][Config.Hud.exportFn](
                Config.Hud.exportName, true, hudText)
        end)
    elseif hudText and hudBackend == 'event' then
        pcall(function()
            TriggerEvent(Config.Hud.eventName, hudText, true)
        end)
    elseif not hudText then
        if hudBackend == 'export' then
            pcall(function()
                exports[Config.Hud.exportName][Config.Hud.exportFn](
                    Config.Hud.exportName, false, '')
            end)
        elseif hudBackend == 'event' then
            pcall(function()
                TriggerEvent(Config.Hud.eventName, '', false)
            end)
        else
            hudNative = false
        end
    end
end

---------------------------------------------------------------------
-- Mission helpers
---------------------------------------------------------------------

local function isInJetPed(ped)
    if not jet or not DoesEntityExist(jet) then return false end
    return ped == GetPedInVehicleSeat(jet, -1)
end

local function spawnPassengers(vehicle)
    -- Seat count comes from the MODEL hash, not the entity:
    -- GetVehicleModelNumberOfSeats(GetEntityModel(veh)).
    -- Seat index 0 is the driver, so passengers fill 1 .. count-1.
    local modelHash = GetEntityModel(vehicle)
    local maxSeats = GetVehicleModelNumberOfSeats(modelHash)

    if not maxSeats or maxSeats <= 0 then
        print('[pilotjob] could not read seat count for the jet model')
        return
    end

    for i = 1, maxSeats - 1 do
        local ped = CreatePedInsideVehicle(vehicle, 4, `a_m_m_business_01`, i, true, false)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            SetPedCanRagdoll(ped, false)
            SetPedCombatAttributes(ped, 46, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetEntityInvincible(ped, true)
            SetEntityAsMissionEntity(ped, true, true)
            SetDriverAbility(ped, 0.0)
            passengers[#passengers + 1] = ped
        end
        Wait(0)   -- one ped per frame; keeps clear of the native buffer cap
    end

    print(('[pilotjob] seated %d passenger(s)'):format(#passengers))
end

local function cleanupPed(ped)
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, false, true)
        DeleteEntity(ped)
    end
end

local function cleanupVehicle()
    if jet and DoesEntityExist(jet) then
        SetEntityAsMissionEntity(jet, false, true)
        DeleteVehicle(jet)
    end
    jet = nil
end

local function removeDropBlip()
    if dropBlip and DoesBlipExist(dropBlip) then
        SetBlipRoute(dropBlip, false)
        RemoveBlip(dropBlip)
    end
    dropBlip = nil
end

local function endMission(success)
    if not jobActive then return end
    jobActive = false

    -- let NPC passengers out of the jet on success (but keep them tracked)
    if success and jet and DoesEntityExist(jet) then
        for i = #passengers, 1, -1 do
            local ped = passengers[i]
            if ped and DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                TaskLeaveVehicle(ped, jet, 0)
            end
        end
        -- table intentionally NOT cleared; the despawn thread below
        -- deletes these peds in the same pass as the jet.
    else
        for i = #passengers, 1, -1 do
            cleanupPed(passengers[i])
        end
        passengers = {}
    end

    removeDropBlip()
    setHud(nil)

    CreateThread(function()
        Wait(Config.DespawnWait * 1000)
        cleanupVehicle()
        for i = #passengers, 1, -1 do
            cleanupPed(passengers[i])
        end
        passengers = {}
    end)

    if success then
        TriggerServerEvent('pilotjob:reward', Config.Payout)
        ESX.ShowNotification(('~g~Delivery complete~s~ - $%s paid'):format(Config.Payout))
    else
        ESX.ShowNotification('~r~Delivery failed~s~ - the passengers were not delivered.')
    end
end

---------------------------------------------------------------------
-- Start the job
---------------------------------------------------------------------

RegisterNetEvent('pilotjob:client:start', function()
    if jobActive then
        ESX.ShowNotification('~y~You are already on a flight.')
        return
    end

    local model = Config.JetModel
    RequestModel(model)
    local timeout = GetGameTimer() + 15000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then
            ESX.ShowNotification('~r~Could not load the Luxor. Try again.')
            return
        end
        Wait(0)
    end

    local spawn = Config.JetSpawn
    jet = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleOnGroundProperly(jet)
    SetEntityAsMissionEntity(jet, true, true)
    SetVehicleHasBeenOwnedByPlayer(jet, true)
    SetVehicleDoorsLocked(jet, 0)
    SetModelAsNoLongerNeeded(model)

    SetPedIntoVehicle(PlayerPedId(), jet, -1)
    Wait(100)   -- give the ped a frame to actually be seated

    passengers = {}
    spawnPassengers(jet)

    jobActive = true
    missionTs = GetGameTimer()

    -- HUD: pure state, no natives, safe to set here
    setHud('Deliver the passengers to the drop-off')

    -- Blips: yield first, then build them. Doing this on the same frame as
    -- CreateVehicle is what silently ate the blip calls.
    CreateThread(function()
        Wait(250)
        removeDropBlip()

        local blip = AddBlipForCoord(DROP_XYZ.x, DROP_XYZ.y, DROP_XYZ.z)
        dropBlip = blip
        SetBlipSprite(blip, Config.DropZone.mapBlip.sprite)
        SetBlipColour(blip, Config.DropZone.mapBlip.color)
        SetBlipScale(blip, Config.DropZone.mapBlip.scale)
        -- Routed objective blip: stays full-map so the route line always works.
        SetBlipAsShortRange(blip, Config.DropZone.mapBlip.shortRange)
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, Config.DropZone.mapBlip.color)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Config.DropZone.mapBlip.label)
        EndTextCommandSetBlipName(blip)
    end)

    ESX.ShowNotification('~g~Flight started~s~ - take your passengers to the drop-off.')
end)

---------------------------------------------------------------------
-- Start zone: E to accept
---------------------------------------------------------------------
-- The start blip is a permanent world-map marker. SetBlipDisplay is the
-- switch that decides WHICH map a blip appears on:
--
--   2  -> main map AND minimap
--   3  -> main map only
--   4  -> main map only
--   5  -> minimap only
--
-- So: build the blip once at full draw distance with display 3 (world map
-- only), then flip it to 2 while the player is near so the minimap picks
-- it up too. SetBlipAsShortRange does not help here -- it hides the blip
-- from BOTH maps until you are close. Neither does SetBlipShowsOnlyOnWorldMap.
---------------------------------------------------------------------

CreateThread(function()
    local startXYZ = vec3(START_POS.x, START_POS.y, START_POS.z)
    local blipRange  = Config.StartZone.blipRange or 100.0
    local markerRange = Config.StartZone.markerRange or 40.0

    local WORLD_MAP_ONLY = 3
    local BOTH_MAPS      = 2

    -- built once, stays for the lifetime of the resource
    startBlip = AddBlipForCoord(START_POS.x, START_POS.y, START_POS.z)
    SetBlipSprite(startBlip, Config.StartZone.mapBlip.sprite)
    SetBlipColour(startBlip, Config.StartZone.mapBlip.color)
    SetBlipScale(startBlip, Config.StartZone.mapBlip.scale)
    SetBlipAsShortRange(startBlip, false)          -- full draw distance
    SetBlipDisplay(startBlip, WORLD_MAP_ONLY)      -- start: world map only
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.StartZone.mapBlip.label)
    EndTextCommandSetBlipName(startBlip)

    local worldMapOnly = true

    while true do
        local sleep = 1000
        local pos = GetEntityCoords(PlayerPedId())
        local dist = #(pos - startXYZ)

        -- near -> minimap gets it too; far -> world map only
        local nearby = dist < blipRange
        if nearby == worldMapOnly then
            worldMapOnly = not nearby
            if DoesBlipExist(startBlip) then
                SetBlipDisplay(startBlip, worldMapOnly and WORLD_MAP_ONLY or BOTH_MAPS)
            end
        end

        -- ground marker + E to accept, only while close
        if dist < markerRange then
            sleep = 0
            DrawMarker(1, START_POS.x, START_POS.y, START_POS.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                3.0, 3.0, 1.0,
                30, 144, 255, 120,
                false, false, 2, false, nil, nil, false)

            if dist < Config.StartZone.markerRadius and not jobActive then
                ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to start the pilot job')
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('pilotjob:client:start')
                end
            end
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- Mission loop: drop marker, objective text, E to finish, fail checks
---------------------------------------------------------------------

CreateThread(function()
    while true do
        local sleep = 1000

        if jobActive then
            sleep = 0
            local playerPed = PlayerPedId()
            local pos = GetEntityCoords(playerPed)

            if not jet or not DoesEntityExist(jet) then
                endMission(false)   -- jet destroyed / removed
            elseif not isInJetPed(playerPed) then
                endMission(false)   -- player bailed out
            else
                local dist = #(pos - DROP_XYZ)

                if dist < Config.DrawDist then
                    DrawMarker(1, DROP_XYZ.x, DROP_XYZ.y, DROP_XYZ.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        8.0, 8.0, 2.0,
                        255, 215, 0, 140,
                        false, false, 2, false, nil, nil, false)
                end

                if dist <= Config.DropZone.requiredDist then
                    setHud('Press E to let the passengers out')
                    ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to let the passengers out')
                    if IsControlJustReleased(0, 38) then
                        endMission(true)
                    end
                else
                    setHud(('Deliver the passengers - %s m'):format(math.floor(dist)))
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupVehicle()
    for i = #passengers, 1, -1 do cleanupPed(passengers[i]) end
    if startBlip and DoesBlipExist(startBlip) then RemoveBlip(startBlip) end
    removeDropBlip()
    setHud(nil)
end)
