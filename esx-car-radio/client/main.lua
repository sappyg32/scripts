local ESX = exports['es_extended']:getSharedObject()
local PlayerData = ESX.GetPlayerData()
local nearRadioVehicle = false
local currentRadioVehicles = {}
local spawnedSounds = {}

-- Update player data on job change and load
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerData.job = job
end)

-- Event to update local list of vehicles with radio on
RegisterNetEvent('esx-car-radio:client:updateRadio', function(vehicleNetId, url)
    if url then
        currentRadioVehicles[vehicleNetId] = url
    else
        currentRadioVehicles[vehicleNetId] = nil
        -- Stop sound if playing for this vehicle
        if spawnedSounds[vehicleNetId] then
            StopSound(spawnedSounds[vehicleNetId])
            spawnedSounds[vehicleNetId] = nil
        end
    end
end)

-- SLOW loop: Check every 1 second for vehicles with radio within distance
CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        nearRadioVehicle = false
        for vehNetId, url in pairs(currentRadioVehicles) do
            local vehicle = NetToVeh(vehNetId)
            if vehicle and DoesEntityExist(vehicle) then
                local vehCoords = GetEntityCoords(vehicle)
                if #(playerCoords - vehCoords) < Config.Distance then
                    nearRadioVehicle = true
                    break
                end
            end
        end
        Wait(1000)
    end
end)

-- FAST loop: Only when near a radio vehicle, handle audio playback
CreateThread(function()
    while true do
        if nearRadioVehicle then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            for vehNetId, url in pairs(currentRadioVehicles) do
                local vehicle = NetToVeh(vehNetId)
                if vehicle and DoesEntityExist(vehicle) then
                    local vehCoords = GetEntityCoords(vehicle)
                    local distance = #(playerCoords - vehCoords)
                    if distance < Config.Distance then
                        -- Play sound at vehicle position if not already playing
                        if not spawnedSounds[vehNetId] then
                            local soundId = GetSoundId()
                            PlaySoundFromCoord(soundId, Config.DefaultSound, vehCoords.x, vehCoords.y, vehCoords.z, 'DLC_MPHEIST_MUSIC_SOUNDS', true, Config.SoundVolume, false)
                            spawnedSounds[vehNetId] = soundId
                        end
                        -- Draw help text to show radio is playing
                        ESX.ShowNotification('Radio is playing: ' .. url)
                    else
                        -- Stop sound if too far
                        if spawnedSounds[vehNetId] then
                            StopSound(spawnedSounds[vehNetId])
                            spawnedSounds[vehNetId] = nil
                        end
                    end
                end
            end
            Wait(0)
        else
            -- Stop all sounds if not near any radio vehicle
            for vehNetId, soundId in pairs(spawnedSounds) do
                StopSound(soundId)
                spawnedSounds[vehNetId] = nil
            end
            Wait(1000)
        end
    end
end)

-- Register /radio command
RegisterCommand(Config.Command, function(source, args)
    local playerPed = PlayerPedId()
    if not IsPedInAnyVehicle(playerPed, false) then
        ESX.ShowNotification('You must be in a vehicle to use the radio.')
        return
    end
    local url = table.concat(args, ' ')
    if url == '' or type(url) ~= 'string' or #url > Config.MaxURLLength then
        ESX.ShowNotification('Invalid YouTube URL. Please provide a valid link.')
        return
    end
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    local vehicleNetId = VehToNet(vehicle)
    TriggerServerEvent('esx-car-radio:server:setRadio', vehicleNetId, url)
end, false)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for vehNetId, soundId in pairs(spawnedSounds) do
        StopSound(soundId)
    end
    spawnedSounds = {}
end)