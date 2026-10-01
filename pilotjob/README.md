# pilotjob

ESX Luxor pilot job with NPC passengers.

## Install
1. Drop the `pilotjob` folder into your resources directory.
2. Add `ensure pilotjob` to server.cfg AFTER `es_extended` and `ox_inventory`.
3. Restart the resource (or the server) after replacing files.

## Flow
- Marker + map blip at vector4(-954.99, -2764.40, 13.94, 281.67). Press E to start.
- A Luxor spawns at vector4(-1665.49, -2784.07, 13.94, 334.30), you are put in the cockpit.
- Every passenger seat is filled with an invincible, non-combative NPC.
- Objective: deliver the passengers to vector4(1563.02, 3217.38, 40.41, 287.00).
  Ground marker + routed map blip + on-screen objective.
- Within 100 ft of the drop zone, press E. All NPCs exit, the jet despawns after
  10 seconds, and you are paid $10,000 into ox_inventory.
- Fail (no payout): you leave the jet early, or the jet is destroyed.

## Blip visibility (Config.StartZone)
The start blip is a permanent world-map marker. It lives for the whole session at
full draw distance, so it is always on the pause/world map. It only joins the
minimap once you are inside `Config.StartZone.blipRange` (default 100 m).

  blipRange    -- distance the blip also shows on the minimap (metres)
  markerRange  -- distance the ground marker draws at (metres)

Two natives matter here, and only the second one controls *which* map:

    SetBlipAsShortRange(blip, false)   -- draw at full distance
    SetBlipDisplay(blip, id)           -- which map it appears on

                                    2  -> main map AND minimap
                                    3  -> main map only
                                    4  -> main map only
                                    5  -> minimap only

The zone thread flips display 3 -> 2 while you are nearby and back to 3 when you
leave. Note that `SetBlipAsShortRange(blip, true)` hides the blip from BOTH maps
until you are close -- it is not a minimap-only switch, which is why it stays
`false` here. `SetBlipShowsOnlyOnWorldMap` is not the right native either.

The drop-zone blip is a routed objective, so it shows on both maps at all times.

## Objective HUD (Config.Hud)
The job reads its on-screen objective through one of three backends, chosen
automatically on first use:

  auto (default) -> try the esx_hud export, then the esx_hud event,
                    then fall back to a built-in native GTA text render.

Every backend call is wrapped in pcall, so a missing or differently-named
export can never break the mission thread.

To pin it:
  Config.Hud.mode = 'native'   -- skip esx_hud entirely, use built-in text
  Config.Hud.mode = 'export'   -- force exports.esx_hud:setObjective(bool, text)
  Config.Hud.mode = 'event'    -- force TriggerEvent('esx_hud:setObjective', ...)
  Config.Hud.mode = 'off'      -- no on-screen objective

If your fork uses a different export name or signature, set exportName/exportFn
(or eventName) in Config.Hud. Check the fork's client file for the real name.
When in doubt, 'native' always works.

## Blip note
Drop-zone blips are created inside their own thread with a short Wait, because
building blips on the same frame as CreateVehicle silently drops the calls on
some builds. If you add more blips, keep them off the vehicle-spawn frame.

## ox_inventory note
Payout uses the 'money' item. Change the item name in server/main.lua if you use
'black_money'. If ox_inventory is not running, or the item add fails, it falls
back to a bank deposit.
