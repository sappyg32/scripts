local ESX = exports['es_extended']:getSharedObject()
local radioVehicles = {}  -- Table to store radio URLs keyed by vehicle net ID
local cooldowns = {}  -- Rate limiting cooldowns

-- Rate limiting cleanup
AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)

-- Server event to set radio for a vehicle
RegisterNetEvent('esx-car-radio:server:setRadio', function(vehicleNetId, url)
    local src = source  -- Capture source FIRST LINE
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end  -- Player exists check
    if type(vehicleNetId) ~= 'number' then return end  -- Type check
    if type(url) ~= 'string' then return end
    if #url > Config.MaxURLLength then return end  -- Length check
    -- Rate limiting
    if cooldowns[src] and os.time() - cooldowns[src] < Config.CooldownSeconds then return end
    cooldowns[src] = os.time()
    -- Validate player is in the vehicle
    local playerPed = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if not vehicle or vehicleNetId ~= VehToNet(vehicle) then return end  -- Security: ensure player is in the vehicle they claim
    -- Store the URL for the vehicle
    radioVehicles[vehicleNetId] = url
    -- Broadcast update to all clients
    TriggerClientEvent('esx-car-radio:client:updateRadio', -1, vehicleNetId, url)
    -- Log or notify
    print('Radio set for vehicle ' .. vehicleNetId .. ' with URL: ' .. url)
end)

-- Cleanup when vehicle is deleted or player leaves
AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) == 2 then  -- Vehicle type
        local vehicleNetId = VehToNet(entity)
        if radioVehicles[vehicleNetId] then
            radioVehicles[vehicleNetId] = nil
            TriggerClientEvent('esx-car-radio:client:updateRadio', -1, vehicleNetId, nil)
        end
    end
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    radioVehicles = {}
    cooldowns = {}
    TriggerClientEvent('esx-car-radio:client:updateRadio', -1, nil, nil)  -- Notify all clients to clear
end)