# FiveM Admin Menu

A standalone FiveM resource providing:

- Admin-only NUI menu
- Player list and search
- Ban with persistent identifier-based bans
- Spectate
- Freeze / unfreeze
- Set player on fire
- Kill
- Explode the vehicle a selected player is currently occupying
- Revive players
- Heal players
- Spawn 4 hostile wild dogs around a selected player
- Spawn vehicles by GTA/FiveM model name from the admin menu
- View and close player reports
- Reply to player reports from the admin menu with an in-game notification to the reporter
- Player report submission through the NUI or `/report [player id] [message]`
- ACE-based server-side authorization

## Install

1. Put the `fivem_admin_menu` folder in your server's resources directory.
2. Add this to `server.cfg`:

```cfg
ensure fivem_admin_menu
add_ace group.admin fivem.admin allow
```

Add your staff identifiers to the admin group using your server's normal ACE setup, for example:

```cfg
add_principal identifier.license:YOUR_LICENSE_HERE group.admin
```

3. Restart the resource/server.
4. Press F10 or type `/admin`.

## Security notes

All privileged actions are validated server-side using ACE permission. Do not rely on NUI visibility for authorization.

Bans are saved in `bans.json` and match any stored player identifier. Back up this file if you want to preserve bans during resource migrations.

Reports are currently stored in server memory and are cleared when the resource/server restarts. For production use, replace the report table with a database such as oxmysql.

## Production hardening

Recommended additions before public deployment:

- oxmysql persistence for reports/bans
- Discord/webhook audit logging
- Staff action logging
- Ban expiration/unban support
- Per-action permissions (e.g. `fivem.admin.ban`, `fivem.admin.kill`)
- Rate limiting for reports
- Server-side reason length/character validation
- Staff-only report visibility and pagination
- Better spectate camera/vehicle handling


## QBCore vehicle keys

Admin-spawned vehicles now trigger the standard QBCore `qb-vehiclekeys` ownership event:

```lua
TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(vehicle))
```

Make sure `qb-vehiclekeys` is started before this admin resource:

```cfg
ensure qb-core
ensure qb-vehiclekeys
ensure fivem_admin_menu
```

If your server uses a replacement keys resource instead of `qb-vehiclekeys`, change the key event in `client/main.lua` to the event/export required by that resource.

## Report reply UI

Report replies use an inline FiveM NUI text box instead of JavaScript `prompt()`.
This keeps reply entry inside the admin menu and avoids opening an external JavaScript/browser dialog.


## v8 fix
Fixed the report Reply button by correctly assigning each rendered report card its `data-report-id` attribute.


## v9 UI overhaul
Rebuilt the NUI with dashboard navigation, live counters, interactive player cards, report filters, inline report replies, confirmation dialogs for destructive actions, quick vehicle spawning, responsive layout, and stacked notifications.


## v10 World Controls
- Day/night server controls
- Global weather presets
- 15-second global earthquake camera-shake effect
- All world actions validated with the existing server-side ACE admin permission

If a separate QBCore weather/time sync resource is active, it may overwrite native time/weather. Integrate these actions with that resource if necessary.

## v11 qb-weathersync integration

World Controls now use qb-weathersync's official server exports:
- `exports['qb-weathersync']:setTime(hour, minute)`
- `exports['qb-weathersync']:setWeather(weather)`

The old native client-side time/weather overrides were removed so they no longer
fight qb-weathersync. Earthquake remains a server-broadcast gameplay-camera effect.

Recommended resource order:
```
ensure qb-core
ensure qb-weathersync
ensure fivem_admin_menu
```

## v12 Environment controls

- Dynamic Weather Enable/Disable uses `qb-weathersync:setDynamicWeather`.
- Blackout Enable/Disable uses `qb-weathersync:setBlackout`.
- Earthquake now causes eligible players who are on foot to intermittently ragdoll during the 15-second quake.
- Players in vehicles are not ragdolled by the earthquake.

## v13 fixes
- Weather/time changes now force an immediate qb-weathersync `RequestStateSync` after the official export updates state.
- Earthquake no longer uses JavaScript `confirm()`; confirmation stays inside the FiveM NUI.
- Earthquake camera intensity reduced to 0.18 and changed to a single gentle road-vibration shake.
- On-foot ragdoll remains, with less frequent falling.
- If `Config.RealTimeSync = true` in qb-weathersync, its real-time loop can later advance/replace manually selected time; disable real-time sync if you want manual admin time to remain authoritative.

## v14 Restart warning sequence

Adds an admin-menu Restart Sequence:
- Forces qb-weathersync to THUNDER and disables dynamic weather.
- Shows a 2-minute severe-weather restart banner to all players.
- Plays a storm/alarm warning sound on each client for roughly 12 seconds.
- Sends countdown milestones.
- Integrates with `txAdmin:events:scheduledRestart`: when txAdmin broadcasts its official 2-minute scheduled-restart event, the storm and siren start automatically.
- The manual menu sequence does NOT kill FXServer by default (`Config.RestartUseQuitCommand = false`).

### Recommended restart setup
Use txAdmin to schedule the actual restart. txAdmin officially emits scheduled restart events at 30, 15, 10, 5, 4, 3, 2, and 1 minutes, so this resource can safely attach the storm/siren to the 2-minute event.

If you deliberately set `Config.RestartUseQuitCommand = true`, the manual sequence runs FiveM's `quit` command after two minutes. Only enable that if your Linux service/process manager is configured to automatically relaunch FXServer after a clean exit.

## v15 Siren loop fix
The restart-warning siren now repeats approximately every 10 seconds for the
entire two-minute countdown instead of stopping after its first playback.
The active sound is cleaned up when the restart countdown ends.

## v16 multiplayer weather/time fix
The admin-selected weather/time is now maintained as authoritative state by this
resource and rebroadcast to every connected player every 2 seconds. Each client
reapplies it locally, and newly joining players receive the current state. The
qb-weathersync exports are still updated as well.

## v17 Player teleport controls
Each player card now includes:
- **Go To** — teleports the admin to the selected player's current location.
- **Bring** — teleports the selected player to the admin's current location.

Teleport requests are authorized server-side with the existing admin ACE check.
If the teleported player is the driver of a vehicle, their vehicle moves with them.

## v18 Teleport fix
Reworked Bring / Go To into a simpler client-server-client coordinate exchange.
The NUI buttons now have a dedicated delegated click handler and explicit
`type="button"`, preventing other player-card click handling from swallowing the
teleport action. Coordinates are sent as individual numeric event arguments
instead of a Lua table, improving FiveM event compatibility.

## v19 Give Item
Player cards now include **Give Item**. Enter a QBCore item spawn name and amount.
The server validates the admin ACE permission, target, amount, and the item against
`QBCore.Shared.Items` before calling the player's `AddItem` function. Maximum amount
per action is 1000. Standard qb-inventory ItemBox notification is triggered.

## v20 NUI Give Item fix
Fixed the `Cannot read properties of null (reading 'addEventListener')` NUI error.
Give Item modal buttons now use delegated document event handling, so they work
regardless of when the modal DOM is parsed by FiveM NUI.

## v21 Give Item freeze fix
The Give Item modal had been inserted *after* `#app` and after the app.js script.
That made it an independent full-screen absolute NUI layer, which looked like the
game had frozen and could leave focus trapped. The modal now lives inside `#app`,
the script loads after the modal markup, and the modal can be dismissed with
Cancel, Escape, or by clicking its backdrop.

## v22 qb-garages ownership fix
Admin-spawned vehicles are now inserted into QBCore's `player_vehicles` table for
the spawning admin. This makes qb-garages recognize the plate as an owned vehicle.
The vehicle model must exist in `QBCore.Shared.Vehicles`; otherwise the admin gets
a notification explaining why it cannot be persisted. The initial database state
is `0` (out), and qb-garages changes it to stored when the vehicle is parked.

## v23 Vehicle transfer
Player cards now include **Transfer Vehicle**. The admin must be sitting in the
vehicle being transferred. After confirmation, the server verifies that the plate
is actually owned by the admin in `player_vehicles`, then changes both `citizenid`
and `license` to the selected online player. The recipient receives qb-vehiclekeys
ownership and can store the vehicle through qb-garages.

This transfers ownership rather than duplicating the database row.

## v24 Remove / Restore Clothes
Player cards now include **Remove Clothes** and **Restore Clothes**. Remove Clothes
changes the target's standard GTA freemode clothing components for top/undershirt,
pants and shoes to minimal/default freemode variants. The affected component
variations are saved client-side and Restore Clothes puts the previous variations
back for that session. No custom nude model or explicit texture is included.

## v25 Player identities
Player cards now display QBCore character first/last name, FiveM/Rockstar display
name, and server ID. Search matches all three.

## v26 Set Job
Player cards include Set Job. Jobs and grades are validated against QBCore.Shared.Jobs and applied with Player.Functions.SetJob.

## v27 Set Job fix
The v26 job event was accidentally registered before the local `isAdmin` and
`notify` functions were declared. In Lua that handler therefore resolved those
names as globals and failed when invoked. v27 registers the handler after the
helpers are defined and explicitly refreshes QBCore player/job data on the target.

## v28 Developer tools
Added a Developer sidebar page with live player coordinate lookup. It displays X,
Y, Z, heading, a ready-to-use `vector3(x, y, z)`, and `vector4(x, y, z, heading)`.
The page includes refresh and copy buttons.

## v29 Player waypoint
Each player card now has **Set Waypoint**. The target client returns its current
coordinates to the server, which relays them only to the requesting authorized
admin. The admin client then uses `SetNewWaypoint(x, y)` to place the GPS waypoint.

## v30 Ragdoll + Developer God Mode
- Player cards include **Ragdoll**, which forces the selected player into ragdoll
  for about five seconds. If they are in a vehicle, the client first attempts to
  make them exit before applying ragdoll.
- Developer Tools includes **God Mode** for the admin's own character. It toggles
  entity/player invincibility and disables ragdoll while active. A maintenance
  loop reapplies the native flags once per second.

## v31 Ragdoll UI fix
Fixed the player-card renderer so the Ragdoll button is actually inserted before
Wild Dogs. The v30 backend/client ragdoll handlers were present, but the UI button
insertion did not survive the generated player-card markup.

## v32 Developer expansion
Added Noclip, Invisible Mode, Teleport to Waypoint, and Entity Debugger to Developer Tools.

## v35 scrolling fix
Adds an explicit bounded scrollbar to the admin workspace and a FiveM NUI wheel
fallback that directly scrolls the main content container. Page Up/Page Down,
Home, and End are also supported while the menu is open.

## v36 Player Management
Adds a Manage Player panel with QBCore identity, job, gang, money, live status, current vehicle information, and quick actions.

## v37 Manage Player fix
Fixed Manage Player assuming `players` was always an array. The handler now
normalizes the existing UI player-state shape before using Array.find().

## v38 Player Management expansion
Manage Player now includes Set Waypoint, Give Item, Set Job, Transfer Vehicle,
Manage Money, and Kick. Money changes and kicks are server-side ACE validated.
Existing item/job/vehicle-transfer interfaces are reused.

## v39 Player Management modal fix
Fixed Give Item / Set Job / Transfer Vehicle using guessed modal field IDs. These
buttons now invoke the already-tested player-card actions. Manage Money and Kick
now close the Player Management overlay before opening their own modal, preventing
hidden modal stacking.

## v40 Fresh Player Info
Refresh Live Info now requests current QBCore PlayerData from the server as well
as live ped/vehicle data. Cash, bank, job, grade, gang, and Citizen ID therefore
refresh immediately after administrative changes such as Give/Remove Money.

## v41 Owned Vehicles / Garage
Manage Player now includes Owned Vehicles. Admins can inspect a character's
player_vehicles rows including model, plate, garage, stored state, fuel, engine,
and body condition. A vehicle can be moved to another qb-garages garage by its
garage spawn/config name. Moving it sets state=1 so qb-garages treats it as stored.
All database operations are server-side and ACE protected.

## v42 Admin Logs
Adds persistent admin_logs.json plus a searchable Admin Logs page. Give/remove money, kicks, and garage moves are recorded server-side. Default retention: 1000 entries.

## v43 Full Audit Logging
Extends the v42 persistent audit system across player moderation/utility actions
and developer/world controls. Existing authoritative server logging remains in
place for money changes, kicks, and owned-vehicle garage moves. Additional UI
actions are sent through an ACE-protected server audit endpoint.

## v44 Navigation Safety Fix
Adds Admin Logs to the page-title metadata and makes go(tab) defensive. Unknown
or future tabs now receive a safe fallback title instead of throwing
"Cannot read properties of undefined (reading '0')".

## v45 World Control Audit Fix
Adds direct audit hooks for the actual World Controls UI selectors so Day/Night,
weather selection/apply, earthquake, and restart controls can be recorded in
Admin Logs instead of relying only on the generic v43 button-ID matcher.

## v46 World Audit Selector Fix
Corrected World Controls logging against the actual markup:
data-world=time with values 12/0 for Day/Night, and #weatherPreset for the selected
weather. Also logs Dynamic Weather and Blackout toggles.

## v47 Vehicle Management
Manage Player now includes Vehicle Management for the vehicle the selected player
is currently inside: Repair, Clean, Refuel, Flip Upright, Unlock, Max Mods, and
Delete Vehicle. Requests are ACE-validated server-side and every vehicle action
is written directly to the persistent Admin Logs.

## v48 Delete Vehicle NUI Freeze Fix
Removed the browser-native confirm() call from Delete Vehicle. FiveM NUI can
hang/freeze on synchronous browser dialogs. Delete Vehicle now uses the admin
menu's own asynchronous confirmation modal before sending the existing
server-validated vehicle delete action.

## v49 Persistent Database Admin Logs
Admin logs now persist in MySQL instead of admin_logs.json. The resource
automatically creates `fivem_admin_logs` through oxmysql and loads the latest
entries directly from the database whenever Admin Logs is refreshed. This fixes
logs disappearing after reconnects/resource or server restarts and avoids
deployment updates overwriting the JSON audit file.

## v50 Warnings + Admin Duty
- Persistent MySQL player warnings tied to QBCore citizenid.
- Manage Player > Warnings shows history and issues a new warning.
- Warned players receive an immediate notification.
- Dashboard Admin Duty toggle with ON/OFF status.
- Duty changes and warnings are written to persistent Admin Logs.

## v51 Warnings Button Fix
The warnings modal and backend were present in v50, but the Warnings button was
not inserted into the actual Manage Player Quick Actions markup. v51 adds the
missing `data-pi-extra="warnings"` button beside Vehicle Management and Manage
Money so the existing warnings handler is reachable.

## v52 Warnings Click Fix
Fixed a data-action mismatch: the Manage Player button sends `warnings`, while
the click handler in v50/v51 was checking for `warn`. The handler now matches
`warnings`, so clicking the button opens the existing warnings modal.

## v53 Always-Visible Admin Report Alerts
When a player submits a report, every connected ACE-authorized admin receives a
styled NUI notification in the upper-right corner even if the admin menu itself
is closed. The alert shows report number, reporter, target when present, and the
report message. It auto-dismisses after 12 seconds or can be dismissed manually.
The existing server already broadcasts `fadm:newReport` only to admins, so no
new permission path is introduced.

## v54 Duty Enforcement
ACE admins now start off duty. Off-duty admins may open the menu only to use the
Dashboard/Go On Duty control. All administrative actions are independently
blocked server-side until duty is active. Off-duty admins do not receive new
report alerts, and report/player data is cleared when going off duty.

## v55 Off-Duty Menu Access Fix
The `/admin` command was still checking `isAdmin()`, which now requires active
duty. That prevented an off-duty admin from opening the menu to go on duty.
Opening `/admin` now checks ACE permission only (`hasAdminAce`); all actual
administrative functions continue to require active duty server-side.

## v56 /report UI
The `/report` command no longer expects command arguments. Running `/report`
opens the existing New Report NUI directly, with fields for the target Server ID
and report details. Submission continues through the existing server-side report
handler, and admins on duty receive the existing styled report notification.

## v57 Player Report Duty-Guard Fix
The off-duty admin click guard was also intercepting the player-facing Submit
Report button. `/report` now enters an explicit player-report mode. In that mode
Submit Report and Close are allowed regardless of admin duty/ACE status, while
all admin controls remain inaccessible. After submission the standalone report
UI closes automatically.

## v58 Announcements + On-Duty Staff
On-duty admins can broadcast Normal, Warning, or Emergency announcements from
the Dashboard. Every connected player receives a centered CSS announcement even
when no admin/report UI is open. Messages are limited to 500 characters and are
recorded in persistent Admin Logs. The Dashboard also includes an On-Duty Staff
roster with admin names and server IDs, refreshed on duty changes or manually.

## v59 Ban Management + Report Claiming
Added an on-duty-only Bans page with active-ban search, details, refresh and
unban. Unbans are recorded in persistent Admin Logs. Reports can now be claimed;
all on-duty admins receive the updated claim state, and another admin cannot
take an already claimed report. The claiming admin can unclaim it.

## v60 Vehicle + Job Browsers
Vehicle spawning now uses a searchable browser populated directly from
QBCore.Shared.Vehicles. Search by model, display name, brand, or category and
spawn with one click. Set Job now loads QBCore.Shared.Jobs into a searchable
selector and dynamically shows only valid grades for the selected job. The
existing server-side job and vehicle validation remains authoritative.

## v61 Spectate Upgrade + Roles
Spectate restores the admin's original position on exit, displays a target HUD,
and supports Left/Right target cycling plus ESC exit.

ACE hierarchy: fivem.moderator < fivem.admin < fivem.superadmin. Existing
fivem.admin setups remain Admin-level. Moderators are blocked server-side from
ban/kill/fire/explode-vehicle, unban, and server announcements. Admin and Super
Admin retain those functions. All staff still require Admin Duty.

## v62 Staff Management + Role-Aware UI
Super Admins now have a Staff page listing connected staff, ACE role, server ID,
and current duty status. The sidebar footer displays the current user's role.
Moderator UI hides Admin-only destructive controls and Ban/Announcement access;
the server-side v61 permission checks remain authoritative. The Staff page is
visible only to Super Admins and its server endpoint independently requires
Super Admin + on-duty authorization.

## v63 Report System v2
Reports and replies now persist in MySQL (`fivem_admin_reports` and
`fivem_admin_report_replies`) and survive resource/server restarts. Existing
pre-v63 in-memory reports cannot be migrated because they were never stored.

Claims are enforced server-side: a report claimed by one staff member cannot
be replied to or closed by another. Replying to an unclaimed report
automatically claims it. Admin/Super Admin can use Take Over to transfer a
claim. Claim/unclaim/takeover/close/reply actions are audit logged. Added a
Claimed-only report filter. Reporter server IDs are retained for live reply
delivery; if the reporter is offline, the reply remains in persistent history.

## v64 Entity Debugger v2
Developer Entity Debugger now raycasts up to 40 meters and displays entity
type/handle/model hash, network ID/network state, network owner server ID,
distance, coordinates, heading, health/max health and visibility. Vehicles add
plate, speed, engine/body/tank health, fuel, dirt, lock status and driver
presence. Peds add player/dead/armor data and, for player peds, the FiveM name
and server ID. Copy Details copies the current inspection as plain text.

## v65 Entity Debugger crash fix
Fixed Entity Debugger v2 failing on local/non-networked entities. Network natives
are now called only when the inspected entity is actually networked and are
additionally protected with pcall. Local map objects now return Networked: No,
Network ID: 0, and Owner: N/A instead of crashing the NUI callback.

## v66 Entity Debugger safe-mode fix
The inspect callback was rewritten around StartShapeTestLosProbe and a conservative
native set. Network ID/owner lookup and other potentially unsafe lookup natives
were removed from the inspection path because native exceptions cannot be caught
reliably by Lua pcall once the game native itself faults. This version prioritizes
a debugger that works reliably for local map objects, peds, and vehicles.

## v67 Entity Debugger raycast correction
Restored the original StartShapeTestRay approach that successfully detected
entities, increased range to 50m, and now waits briefly for the asynchronous
shape test to complete instead of assuming the result is immediately ready.
The unsafe network lookup natives remain removed.

## v68 UI Cleanup
The Players page no longer duplicates every administrative action on each player
card. Player cards are now compact and route actions through Manage Player.

Manage Player has been reorganized into Movement & Observation, Player State,
Character & Economy, Vehicles, and Moderation groups. Identity/QBCore information
uses a cleaner two-column overview on larger displays. No server-side behavior,
permissions, report logic, or the working v67 Entity Debugger raycast was changed.

## v69 UI cleanup correction
Restored Manage Player actions that were unintentionally omitted by the v68
visual cleanup: Remove Clothes, Restore Clothes, Wild Dogs, Set Fire, Explode
Vehicle, and Ban. Existing newer management actions remain available.

The Players page now isolates scrolling to the player-results list. The player
name/server-ID search toolbar remains fixed at the top instead of scrolling with
the player management results.

The working v67 Entity Debugger raycast and server-side behavior remain unchanged.

## v70 UI fixes
- Fixed Remove Clothes in Manage Player. The UI was sending `strip`, while the
  existing server action is `stripclothes`, causing "strip sent" followed by
  "Unknown action".
- Fixed the Players search position. Page navigation now resets the shared main
  scroll position, and the Players page uses its own results scroller so the
  search bar stays at the top.
- Mouse-wheel scrolling on Players now scrolls the player results instead of
  moving the whole admin workspace.
