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
