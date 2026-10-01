local entered = {}
local cooldown = {}

function DistanceCheckLocations(src, locations)
    local pCoords = GetEntityCoords(GetPlayerPed(src))
    local dist

    for k, v in pairs(locations) do
        dist = #(pCoords - v)
        if #(pCoords - v) < Config.TargetDistance + 0.5 then
            dist = #(pCoords - v)
            break
        end
    end

    if dist > 5 then
        DropPlayer(src, 'Attempted Cheating - yetti_robcontainers - server')
        return false
    end

    return true
end

function IsNearCrate(src)
    local pCoords = GetEntityCoords(GetPlayerPed(src))

    for _, v in pairs(Config.ContainerCoords) do
        -- crate spawns with offsets: -5 X, -10 Z
        local crateCoords = vector3(v.x - 5, v.y, v.z - 10)
        local dist = #(pCoords - crateCoords)

        if dist <= Config.TargetDistance + 0.5 then
            return true
        end
    end

    DropPlayer(src, 'Attempted Cheating - yetti_robcontainers - server')

    return false
end

RegisterNetEvent('yetti_robcontainers:server:left', function ()
    local src = source

    if DistanceCheckLocations(src, Config.ContainerCoords) then
        entered[src] = false
    end
end)

RegisterNetEvent('yetti_robcontainers:server:entered', function ()
    local src = source

    if DistanceCheckLocations(src, Config.ContainerCoords) then
        entered[src] = true
    end
end)

RegisterNetEvent('yetti_robcontainers:server:removeItem', function (item)
    if not entered[source] then
        exports.ox_inventory:RemoveItem(source, item, 1)
    end
end)

RegisterNetEvent('yetti_robcontainers:server:reward', function (index)
    local src = source
    local i = tonumber(index)

    -- must reference a real container
    if not i or not Config.ContainerCoords[i] then
        print(('[yetti_robcontainers] reward rejected: bad index %s from %s'):format(tostring(index), src))
        return
    end

    -- per-container guard: this container can only pay once per job round
    if cooldown[src] and cooldown[src][i] then
        print(('[yetti_robcontainers] reward rejected: container %s already paid to %s'):format(i, src))
        return
    end

    local v = Config.ContainerCoords[i]
    local pCoords = GetEntityCoords(GetPlayerPed(src))
    local dist = #(pCoords - v)

    -- The container and its loot zone are both at the container coord now.
    -- Allow a generous radius: the target zone is 3.0 tall and the player
    -- stands on the ground beside the crate.
    if dist > 5.0 then
        print(('[yetti_robcontainers] reward rejected: %s is %.1fm from container %s'):format(src, dist, i))
        return
    end

    cooldown[src] = cooldown[src] or {}
    cooldown[src][i] = true

    Citizen.CreateThread(function ()
        Wait(Config.Cooldown * 1000)
        if cooldown[src] then cooldown[src][i] = false end
    end)

    -- ===== every container pays 5000 marked bills, per container =====
    local payout

    if Config.MarkedBillsMetadata then
        payout = exports.ox_inventory:AddItem(src, Config.DirtyMoneyItem, 1, {
            worth = Config.ContainerPayout,
        })
    else
        payout = exports.ox_inventory:AddItem(src, Config.DirtyMoneyItem, Config.ContainerPayout)
    end

    if not payout then
        print(('[yetti_robcontainers] AddItem FAILED: item "%s" for %s - does that item exist in ox_inventory?'):format(
            Config.DirtyMoneyItem, src))
    else
        print(('[yetti_robcontainers] paid %s x%s to %s (container %s)'):format(
            Config.DirtyMoneyItem, Config.ContainerPayout, src, i))
    end
end)

-- ==========================================================
--  /endrobbery  --  clear this player's per-container payout locks
-- ==========================================================

RegisterNetEvent('yetti_robcontainers:server:reset', function ()
    local src = source

    cooldown[src] = {}
    entered[src] = false

    print(('[yetti_robcontainers] job reset for %s'):format(src))
end)

-- tidy up when a player drops so the tables do not grow forever
AddEventHandler('playerDropped', function ()
    local src = source
    cooldown[src] = nil
    entered[src] = nil
end)
