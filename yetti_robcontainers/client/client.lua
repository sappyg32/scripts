--
--- Main Loop
---

local npcBlip        = nil
local containerBlips = {}
local jobsActive     = false
local completed      = {}   -- container index -> true
local requestReady   = true

-- jobFinished: the round ended (all containers looted, or a reset was run)
-- and the markers must STAY off the map until the NPC hands out a new job.
local jobFinished    = false

-- Per-container interaction state, keyed by container index.
-- Declared at file scope (previously they were upvalues inside the
-- spawn loop) so /endrobbery can reset every container from one place.
--
-- IMPORTANT: every target zone closes over THIS table. Never reassign
-- containerState (`containerState = {}`) - that swaps the variable out
-- from under the zones while they keep reading the original table, and
-- the break-in / loot options silently stop appearing. Clear it in
-- place with ResetContainerState() instead.
local containerState = {}

local function ResetContainerState()
    for k in ipairs(Config.ContainerCoords) do
        containerState[k] = {
            inCooldown = false,
            brokenIn   = false,
            claimedBox = false,
        }
    end
end

ResetContainerState()

function SendDispatch()
    if Config.Dispatch == 'none' then return end

    if Config.Dispatch == 'ps' then
        exports['ps-dispatch']:SuspiciousActivity()
    elseif Config.Dispatch == 'cd' then
        local data = exports['cd_dispatch']:GetPlayerInfo()
        TriggerServerEvent('cd_dispatch:AddNotification', {
            job_table = Config.PoliceJobs,
            coords = data.coords,
            title = Config.DispatchCode,
            message = Config.DispatchMessage,
            flash = 0,
            unique_id = data.unique_id,
            sound = 1,
            blip = {
                sprite = 66,
                scale = 0.7,
                colour = 0,
                flashes = false,
                text = Config.DispatchCode,
                time = 5,
                radius = 0,
            }
        })
    end
end

-- ==========================================================
--  BLIP HELPERS
-- ==========================================================

local function AddContainerBlip(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.ContainerBlip.sprite)
    SetBlipColour(blip, Config.ContainerBlip.colour)
    SetBlipScale(blip, Config.ContainerBlip.scale)
    SetBlipAsShortRange(blip, Config.ContainerBlip.shortRange)
    SetBlipRoute(blip, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.ContainerBlip.label)
    EndTextCommandSetBlipName(blip)

    return blip
end

local function ClearContainerBlips()
    for _, blip in pairs(containerBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end

    containerBlips = {}
    jobsActive = false
end

local function AllContainersDone()
    for i = 1, #Config.ContainerCoords do
        if not completed[i] then return false end
    end
    return true
end

local function ShowContainerBlips()
    ClearContainerBlips()

    for i, coords in ipairs(Config.ContainerCoords) do
        if not completed[i] then
            containerBlips[i] = AddContainerBlip(coords)
        end
    end

    jobsActive = true
end

-- ==========================================================
--  REQUEST COOLDOWN (10 minutes)
-- ==========================================================

local function StartRequestCooldown()
    requestReady = false

    SetTimeout(Config.RequestCooldown * 1000, function()
        requestReady = true
    end)
end

-- ==========================================================
--  NPC BLIP (permanent - never removed)
-- ==========================================================

CreateThread(function()
    npcBlip = AddBlipForCoord(Config.Npc.coords.x, Config.Npc.coords.y, Config.Npc.coords.z)
    SetBlipSprite(npcBlip, Config.Npc.blip.sprite)
    SetBlipColour(npcBlip, Config.Npc.blip.colour)
    SetBlipScale(npcBlip, Config.Npc.blip.scale)
    SetBlipAsShortRange(npcBlip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Npc.blip.label)
    EndTextCommandSetBlipName(npcBlip)
end)

-- ==========================================================
--  GANG NPC  -- spawn + interact
-- ==========================================================

CreateThread(function()
    local model = Config.Npc.model

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local ped = CreatePed(4, model,
        Config.Npc.coords.x,
        Config.Npc.coords.y,
        Config.Npc.coords.z - 1.0,
        Config.Npc.coords.w,
        false,
        true)

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedCanRagdoll(ped, false)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_DRUG_DEALER', 0, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            label = Config.Npc.label,
            icon = Config.Npc.icon,
            distance = Config.TargetDistance,

            canInteract = function ()
                return true
            end,

            onSelect = function ()
                if not requestReady then
                    lib.notify({
                        title = Config.NoJobTitle,
                        description = Config.NoJobDescription,
                        type = 'error',
                    })
                    return
                end

                local itemCount = exports.ox_inventory:Search('count', Config.RequiredItem)
                if itemCount < 1 then
                    lib.notify({
                        title = Config.NotifyTitle,
                        description = Config.NotifyDescription,
                        type = 'error',
                    })
                    return
                end

                completed = {}
                ResetContainerState()
                jobFinished = false        -- markers allowed on the map again
                ShowContainerBlips()

                lib.notify({
                    title = Config.JobTitle,
                    description = Config.JobDescription,
                    type = 'success',
                })
            end,
        },
    })
end)

-- ==========================================================
--  CONTAINERS
-- ==========================================================

for k, v in ipairs(Config.ContainerCoords) do
    local coords = v

    -- this container's interaction state (see containerState above)
    containerState[k] = {
        inCooldown = false,
        brokenIn   = false,
        claimedBox = false,
    }

    exports.ox_target:addBoxZone({
        coords = vector3(coords.x, coords.y, coords.z + 0.25),
        size = vector3(1.2, 1.2, 3.0),
        rotation = 0.0,
        debug = Config.Debug,
        options = {
            {
                label = Config.TargetLabelBreak,
                icon = Config.TargetIconBreak,
                distance = Config.TargetDistance,

                canInteract = function ()
                    local st = containerState[k]
                    if not st then return false end
                    if Config.UseNpcRequest and not jobsActive then return false end
                    if completed[k] then return false end
                    return not st.inCooldown
                end,

                onSelect = function (source)
                    local st = containerState[k]
                    if not st then return end

                    local itemCount = exports.ox_inventory:Search('count', Config.RequiredItem)

                    if itemCount >= 1 then
                        local success = lib.skillCheck({'medium', 'easy', 'medium', 'easy'}, {'e'})

                        if success then
                            -- No teleport: the break-in completes in place.
                            TriggerServerEvent('yetti_robcontainers:server:entered')

                            st.inCooldown = true
                            st.brokenIn = true

                            -- completion bookkeeping
                            completed[k] = true

                            -- remove this container's blip once entered
                            if containerBlips[k] and DoesBlipExist(containerBlips[k]) then
                                RemoveBlip(containerBlips[k])
                                containerBlips[k] = nil
                            end
                        else
                            lib.notify({
                                title = Config.FailTitle,
                                description = Config.FailDescription,
                                type = 'error',
                            })
                        end
                    else
                        lib.notify({
                            title = Config.NotifyTitle,
                            description = Config.NotifyDescription,
                            type = 'error',
                        })
                    end
                end,
            },
        },
    })

    ------------------------------------------------------------------
    --  BOX (loot) ZONE
    --  Sits on the container itself - there is no shell interior and
    --  no teleport, so no -5 X / -10 Z offset.
    ------------------------------------------------------------------
    exports.ox_target:addBoxZone({
        coords = vector3(coords.x, coords.y, coords.z + 0.25),
        size = vector3(1.2, 1.2, 3.0),
        rotation = 0.0,
        debug = Config.Debug,
        options = {
            {
                label = Config.TargetLabelBox,
                icon = Config.TargetIconBox,
                distance = Config.TargetDistance,

                canInteract = function ()
                    local st = containerState[k]
                    if not st then return false end
                    -- loot box is only available after breaking into this container
                    if not st.brokenIn then return false end
                    return not st.claimedBox
                end,

                onSelect = function (source)
                    local st = containerState[k]
                    if not st then return end
                    if st.claimedBox then return end

                    -- belt and braces: refuse the action if break-in never happened
                    if not st.brokenIn then
                        lib.notify({
                            title = Config.FailTitle,
                            description = 'You need to break into the container first',
                            type = 'error',
                        })
                        return
                    end

                    -- lockpick minigame on the container itself
                    local success = lib.skillCheck({'medium', 'easy', 'medium', 'easy'}, {'e'})

                    if not success then
                        st.inCooldown = true
                        SetTimeout(Config.Cooldown * 1000, function()
                            st.inCooldown = false
                        end)

                        lib.notify({
                            title = Config.FailTitle,
                            description = Config.FailDescription,
                            type = 'error',
                        })
                        return
                    end

                    -- minigame passed: pay this container
                    TriggerServerEvent('yetti_robcontainers:server:reward', k)

                    st.claimedBox = true
                    completed[k] = true

                    if AllContainersDone() then
                        jobFinished = true
                        ClearContainerBlips()
                        StartRequestCooldown()

                        lib.notify({
                            title = Config.CompletedTitle,
                            description = Config.CompletedDescription,
                            type = 'inform',
                        })
                    end
                end,
            },
        },
    })
end

-- ==========================================================
--  /endrobbery  --  reset the job + remove the map markers
-- ==========================================================

local function EndRobbery(source)
    local src = source or 0

    -- 1. kill every container blip
    ClearContainerBlips()

    -- 2. clear client-side progress
    completed = {}
    ResetContainerState()

    -- 3. markers stay OFF until the NPC gives out a new job
    jobFinished = true

    -- 4. free the NPC request immediately (normally a 10 minute wait)
    requestReady = true

    -- 5. clear the server-side payout locks for this player
    TriggerServerEvent('yetti_robcontainers:server:reset')

    lib.notify({
        title = 'Robbery Reset',
        description = 'The container job has been reset and the markers have been removed.',
        type = 'inform',
    })
end

RegisterCommand('endrobbery', function (source)
    EndRobbery(source)
end, false)

-- optional: expose it to other scripts / a radial menu / a keybind
exports('EndRobbery', EndRobbery)
