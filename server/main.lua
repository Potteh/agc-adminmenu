


local RESOURCE = GetCurrentResourceName()
local bans = {}
local reports = {}
local nextReportId = 1

local function isAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, Config.AdminAce)
end

local function notify(src, msg)
    TriggerClientEvent('fadm:notify', src, msg)
end

local function setPlayerJob(src, target, jobName, grade)
    if not isAdmin(src) then return end

    target = tonumber(target)
    jobName = tostring(jobName or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    grade = math.floor(tonumber(grade) or 0)

    if not target or not GetPlayerName(target) then
        notify(src, 'Target player is no longer online.')
        return
    end

    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(target)
    if not Player then
        notify(src, 'Target QBCore character is not loaded.')
        return
    end

    local job = QBCore.Shared.Jobs[jobName]
    if not job then
        notify(src, ('Unknown job "%s". Use the spawn name from qb-core/shared/jobs.lua.'):format(jobName))
        return
    end

    local gd = job.grades and (job.grades[tostring(grade)] or job.grades[grade])
    if not gd then
        notify(src, ('Grade %s does not exist for %s.'):format(grade, job.label or jobName))
        return
    end

    -- Current QBCore SetJob accepts the grade as a number and updates PlayerData
    -- plus the persistent players.job JSON through UpdatePlayerData/Save.
    local success = Player.Functions.SetJob(jobName, grade)
    if not success then
        notify(src, ('Failed to set %s to %s grade %s.'):format(GetPlayerName(target), jobName, grade))
        return
    end

    -- Explicitly push the refreshed PlayerData to the target for HUD/job scripts
    -- that rely on the standard QBCore client update event.
    TriggerClientEvent('QBCore:Player:SetPlayerData', target, Player.PlayerData)
    TriggerClientEvent('QBCore:Client:OnJobUpdate', target, Player.PlayerData.job)

    notify(src, ('%s is now %s - %s (grade %s).'):format(
        GetPlayerName(target), job.label or jobName, gd.name or tostring(grade), grade))
    notify(target, ('Your job is now %s - %s (grade %s).'):format(
        job.label or jobName, gd.name or tostring(grade), grade))
end


-- v29: set an admin's map waypoint to an online player's current position.
RegisterNetEvent('fadm:waypointToPlayer', function(target)
    local src = source
    if not isAdmin(src) then return end

    target = tonumber(target)
    if not target or not GetPlayerName(target) then
        notify(src, 'Target player is no longer online.')
        return
    end

    TriggerClientEvent('fadm:requestWaypointCoords', target, src)
end)

RegisterNetEvent('fadm:waypointCoordsResponse', function(adminSrc, x, y, z)
    local targetSrc = source
    adminSrc = tonumber(adminSrc)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)

    if not adminSrc or not GetPlayerName(adminSrc) or not isAdmin(adminSrc) then return end
    if not x or not y or not z then return end

    TriggerClientEvent('fadm:setWaypointCoords', adminSrc, x, y, z, GetPlayerName(targetSrc) or ('Player '..targetSrc))
end)

RegisterNetEvent('fadm:setPlayerJob', function(target, jobName, grade)
    setPlayerJob(source, target, jobName, grade)
end)

local function loadBans()
    local raw = LoadResourceFile(RESOURCE, Config.BanFile)
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then
            bans = data
        end
    end
end

local function saveBans()
    SaveResourceFile(RESOURCE, Config.BanFile, json.encode(bans), -1)
end

local function identifiers(src)
    local out = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        out[#out + 1] = id
    end
    return out
end

local function findBan(src)
    local ids = identifiers(src)
    for _, ban in pairs(bans) do
        for _, bid in ipairs(ban.identifiers or {}) do
            for _, id in ipairs(ids) do
                if bid == id then
                    return ban
                end
            end
        end
    end
    return nil
end

local function playerList()
    local list = {}
    local QBCore = exports['qb-core']:GetCoreObject()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local platformName = GetPlayerName(src) or ('Player ' .. src)
        local characterName = 'Character not loaded'
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.charinfo then
            local ci = Player.PlayerData.charinfo
            local full = (tostring(ci.firstname or '') .. ' ' .. tostring(ci.lastname or '')):gsub('^%s+',''):gsub('%s+$','')
            if full ~= '' then characterName = full end
        end
        local pd = Player and Player.PlayerData or {}
        local job = pd.job or {}
        local grade = job.grade or {}
        local money = pd.money or {}
        list[#list+1] = {
            id=src, name=platformName, rockstarName=platformName, characterName=characterName,
            citizenid=pd.citizenid or 'N/A',
            jobName=job.name or 'unemployed', jobLabel=job.label or job.name or 'Unemployed',
            jobGrade=tonumber(grade.level or grade) or 0, jobGradeName=grade.name or '',
            gang=(pd.gang and (pd.gang.label or pd.gang.name)) or 'None',
            cash=tonumber(money.cash) or 0, bank=tonumber(money.bank) or 0
        }
    end
    table.sort(list,function(x,y) return x.id < y.id end)
    return list
end

loadBans()

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local ban = findBan(src)
    if ban then
        deferrals.done(('You are banned. Reason: %s | Ban ID: %s'):format(
            ban.reason or 'No reason provided',
            ban.id or 'unknown'
        ))
        return
    end

    deferrals.done()
end)

RegisterNetEvent('fadm:getData', function()
    local src = source
    if not isAdmin(src) then return end

    TriggerClientEvent('fadm:openData', src, {
        players = playerList(),
        reports = reports
    })
end)

RegisterNetEvent('fadm:refresh', function()
    local src = source
    if not isAdmin(src) then return end
    TriggerClientEvent('fadm:updateData', src, {
        players = playerList(),
        reports = reports
    })
end)

RegisterNetEvent('fadm:action', function(action, target, reason)
    local src = source
    if not isAdmin(src) then
        print(('^1[FiveM Admin]^7 Unauthorized action from %s'):format(src))
        return
    end

    target = tonumber(target)
    if not target or not GetPlayerName(target) then
        notify(src, 'Invalid player.')
        return
    end

    if action == 'ban' then
        reason = tostring(reason or 'Banned by administrator')
        local ban = {
            id = ('BAN-%d-%d'):format(os.time(), math.random(1000,9999)),
            player = GetPlayerName(target),
            reason = reason,
            identifiers = identifiers(target),
            created = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            admin = GetPlayerName(src) or 'Console'
        }

        bans[#bans + 1] = ban
        saveBans()
        DropPlayer(target, ('You have been banned. Reason: %s | Ban ID: %s'):format(reason, ban.id))
        notify(src, ('Banned %s.'):format(ban.player))

    elseif action == 'freeze' then
        TriggerClientEvent('fadm:setFreeze', target, true)
        notify(src, ('Froze %s.'):format(GetPlayerName(target)))

    elseif action == 'unfreeze' then
        TriggerClientEvent('fadm:setFreeze', target, false)
        notify(src, ('Unfroze %s.'):format(GetPlayerName(target)))

    elseif action == 'fire' then
        TriggerClientEvent('fadm:setFire', target, Config.FireDurationMs)
        notify(src, ('Set %s on fire.'):format(GetPlayerName(target)))

    elseif action == 'kill' then
        TriggerClientEvent('fadm:kill', target)
        notify(src, ('Killed %s.'):format(GetPlayerName(target)))

    elseif action == 'explodevehicle' then
        TriggerClientEvent('fadm:explodeVehicle', target)
        notify(src, ('Triggered vehicle explosion for %s.'):format(GetPlayerName(target)))

    elseif action == 'revive' then
        TriggerClientEvent('fadm:revive', target)
        notify(src, ('Revived %s.'):format(GetPlayerName(target)))

    elseif action == 'heal' then
        TriggerClientEvent('fadm:heal', target)
        notify(src, ('Healed %s.'):format(GetPlayerName(target)))

    elseif action == 'dogs' then
        TriggerClientEvent('fadm:wildDogs', target, 4)
        notify(src, ('Spawned wild dogs around %s.'):format(GetPlayerName(target)))

    elseif action == 'spawnvehicle' then
        -- Vehicle spawning is for the admin who issued the action.
        local modelName = tostring(reason or ''):lower():gsub('%s+', '')
        if modelName == '' or #modelName > 50 or not modelName:match('^[%w_%-]+$') then
            notify(src, 'Invalid vehicle model name.')
            return
        end
        TriggerClientEvent('fadm:spawnVehicle', src, modelName)

    elseif action == 'ragdoll' then
        TriggerClientEvent('fadm:ragdollPlayer', target)
        notify(src, ('Ragdolled %s.'):format(GetPlayerName(target)))

    elseif action == 'stripclothes' then
        TriggerClientEvent('fadm:stripClothes', target)
        notify(src, ('Removed shirt, pants, and shoes from %s.'):format(GetPlayerName(target)))

    elseif action == 'restoreclothes' then
        TriggerClientEvent('fadm:restoreClothes', target)
        notify(src, ('Restored clothing for %s.'):format(GetPlayerName(target)))

    elseif action == 'spectate' then
        TriggerClientEvent('fadm:spectate', src, target)
    else
        notify(src, 'Unknown action.')
    end
end)


RegisterNetEvent('fadm:spawnVehicleRequest', function(modelName)
    local src = source
    if not isAdmin(src) then
        print(('^1[FiveM Admin]^7 Unauthorized vehicle spawn request from %s'):format(src))
        return
    end

    modelName = tostring(modelName or ''):lower():gsub('%s+', '')
    if modelName == '' or #modelName > 50 or not modelName:match('^[%w_%-]+$') then
        notify(src, 'Invalid vehicle model name.')
        return
    end

    TriggerClientEvent('fadm:spawnVehicle', src, modelName)
end)



-- v23: transfer an owned vehicle to another online player.
RegisterNetEvent('fadm:transferVehicle', function(target, plate)
    local src = source
    if not isAdmin(src) then return end

    target = tonumber(target)
    plate = tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if not target or not GetPlayerName(target) then
        notify(src, 'Target player is no longer online.')
        return
    end
    if target == src then
        notify(src, 'That vehicle already belongs to you.')
        return
    end
    if plate == '' then
        notify(src, 'Could not read the vehicle plate.')
        return
    end

    local QBCore = exports['qb-core']:GetCoreObject()
    local Admin = QBCore.Functions.GetPlayer(src)
    local Recipient = QBCore.Functions.GetPlayer(target)
    if not Admin or not Recipient then
        notify(src, 'Could not find one of the QBCore players.')
        return
    end

    -- Only transfer a vehicle actually owned by the requesting admin.
    local owned = MySQL.single.await(
        'SELECT id, vehicle, plate FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1',
        { Admin.PlayerData.citizenid, plate }
    )
    if not owned then
        notify(src, ('You do not own vehicle [%s], so it cannot be transferred.'):format(plate))
        return
    end

    -- Update both citizenid and license so qb-garages recognizes the recipient.
    MySQL.update.await(
        'UPDATE player_vehicles SET citizenid = ?, license = ?, state = 0 WHERE id = ?',
        { Recipient.PlayerData.citizenid, Recipient.PlayerData.license, owned.id }
    )

    notify(src, ('Transferred %s [%s] to %s.'):format(
        owned.vehicle or 'vehicle', plate, GetPlayerName(target)
    ))
    notify(target, ('%s transferred vehicle %s [%s] to you. You can now store it in your garage.'):format(
        GetPlayerName(src) or 'An admin', owned.vehicle or 'vehicle', plate
    ))

    -- Give the recipient keys to the transferred vehicle if their key resource
    -- uses the standard qb-vehiclekeys SetOwner event.
    TriggerClientEvent('fadm:receiveTransferredVehicleKeys', target, plate)
end)

-- v22: persist admin-spawned vehicles so qb-garages recognizes them as owned.
RegisterNetEvent('fadm:registerSpawnedVehicle', function(modelName, plate, props)
    local src = source
    if not isAdmin(src) then return end

    modelName = tostring(modelName or ''):lower():gsub('%s+', '')
    plate = tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if modelName == '' or plate == '' then
        notify(src, 'Could not register spawned vehicle.')
        return
    end

    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- qb-garages can only persist vehicles known to QBCore.Shared.Vehicles.
    local sharedVehicle = QBCore.Shared.Vehicles[modelName]
    if not sharedVehicle then
        notify(src, ('%s spawned, but is not in QBCore.Shared.Vehicles so qb-garages cannot store it.'):format(modelName))
        return
    end

    local existing = MySQL.scalar.await('SELECT id FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if existing then return end

    local garage = 'pillboxgarage'
    local encodedProps = json.encode(type(props) == 'table' and props or {})

    MySQL.insert.await([[
        INSERT INTO player_vehicles
            (license, citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        modelName,
        tostring(joaat(modelName)),
        encodedProps,
        plate,
        garage,
        100,
        1000.0,
        1000.0,
        0
    })

    notify(src, ('Vehicle %s [%s] is now registered to you and can be stored in qb-garages.'):format(modelName, plate))
end)

RegisterNetEvent('fadm:submitReport', function(target, message)
    local src = source
    message = tostring(message or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if #message < 3 then
        notify(src, 'Report is too short.')
        return
    end

    if #message > Config.MaxReportLength then
        message = message:sub(1, Config.MaxReportLength)
    end

    target = tonumber(target)
    if target and not GetPlayerName(target) then
        target = nil
    end

    local report = {
        id = nextReportId,
        reporter = GetPlayerName(src) or ('Player ' .. src),
        reporterId = src,
        target = target,
        targetName = target and GetPlayerName(target) or 'None',
        message = message,
        created = os.date('%Y-%m-%d %H:%M:%S'),
        status = 'open'
    }

    nextReportId = nextReportId + 1
    reports[#reports + 1] = report

    notify(src, ('Report #%d submitted.'):format(report.id))

    for _, id in ipairs(GetPlayers()) do
        local admin = tonumber(id)
        if isAdmin(admin) then
            TriggerClientEvent('fadm:newReport', admin, report)
        end
    end
end)


RegisterNetEvent('fadm:replyReport', function(reportId, message)
    local src = source
    if not isAdmin(src) then return end

    reportId = tonumber(reportId)
    message = tostring(message or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if not reportId or #message < 1 then
        notify(src, 'Enter a reply message.')
        return
    end

    if #message > 500 then
        message = message:sub(1, 500)
    end

    local found = nil
    for _, report in ipairs(reports) do
        if report.id == reportId then
            found = report
            break
        end
    end

    if not found then
        notify(src, 'Report not found.')
        return
    end

    found.replies = found.replies or {}
    found.replies[#found.replies + 1] = {
        admin = GetPlayerName(src) or 'Admin',
        message = message,
        created = os.date('%Y-%m-%d %H:%M:%S')
    }

    local reporterId = tonumber(found.reporterId)
    if reporterId and GetPlayerName(reporterId) then
        TriggerClientEvent('fadm:reportReply', reporterId, {
            reportId = found.id,
            admin = GetPlayerName(src) or 'Admin',
            message = message
        })
        notify(src, ('Reply sent to %s for report #%d.'):format(GetPlayerName(reporterId), found.id))
    else
        notify(src, ('Reply saved, but the reporter for report #%d is offline.'):format(found.id))
    end

    -- Refresh all online admins so the reply appears immediately.
    for _, id in ipairs(GetPlayers()) do
        local admin = tonumber(id)
        if isAdmin(admin) then
            TriggerClientEvent('fadm:updateData', admin, {
                players = playerList(),
                reports = reports
            })
        end
    end
end)

RegisterNetEvent('fadm:closeReport', function(reportId)
    local src = source
    if not isAdmin(src) then return end

    reportId = tonumber(reportId)
    for _, report in ipairs(reports) do
        if report.id == reportId then
            report.status = 'closed'
            report.closedBy = GetPlayerName(src) or 'Console'
            notify(src, ('Closed report #%d.'):format(reportId))
            break
        end
    end

    TriggerClientEvent('fadm:updateData', src, {
        players = playerList(),
        reports = reports
    })
end)

RegisterCommand('admin', function(src)
    if not isAdmin(src) then
        notify(src, 'You do not have permission to use the admin menu.')
        return
    end
    TriggerClientEvent('fadm:open', src)
end, false)


local adminWorldState = { weather=nil, hour=nil, minute=0, active=false }

local function broadcastAdminWorldState()
    if adminWorldState.active then
        TriggerClientEvent('fadm:syncAdminWorldState', -1, adminWorldState)
    end
end

CreateThread(function()
    while true do
        Wait(tonumber(Config.AdminWorldSyncIntervalMs) or 2000)
        broadcastAdminWorldState()
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(5000, function()
        if adminWorldState.active then
            TriggerClientEvent('fadm:syncAdminWorldState', src, adminWorldState)
        end
    end)
end)

RegisterNetEvent('fadm:worldAction', function(action, value)
    local src = source
    if not isAdmin(src) then return end

    if GetResourceState('qb-weathersync') ~= 'started' then
        notify(src, 'qb-weathersync is not running.')
        return
    end

    if action == 'time' then
        local hour = tonumber(value)
        if hour ~= 0 and hour ~= 12 then return end

        local success = exports['qb-weathersync']:setTime(hour, 0)
        if success then
            adminWorldState.hour = hour
            adminWorldState.minute = 0
            adminWorldState.active = true
            TriggerEvent('qb-weathersync:server:RequestStateSync')
            broadcastAdminWorldState()
            notify(src, hour == 0 and 'Server changed to night.' or 'Server changed to day.')
        else
            notify(src, 'Unable to change server time.')
        end

    elseif action == 'weather' then
        local allowed = {
            CLEAR=true, EXTRASUNNY=true, CLOUDS=true, OVERCAST=true,
            RAIN=true, THUNDER=true, FOGGY=true, SMOG=true, SNOW=true,
            BLIZZARD=true, XMAS=true
        }

        local weather = tostring(value or ''):upper()
        if not allowed[weather] then
            notify(src, 'Invalid weather preset.')
            return
        end

        local success = exports['qb-weathersync']:setWeather(weather)
        if success then
            adminWorldState.weather = weather
            adminWorldState.active = true
            TriggerEvent('qb-weathersync:server:RequestStateSync')
            broadcastAdminWorldState()
            notify(src, ('Weather changed to %s.'):format(weather))
        else
            notify(src, ('qb-weathersync rejected weather type %s.'):format(weather))
        end

    elseif action == 'dynamicweather' then
        local enabled = value == true or value == 'true' or value == 1 or value == '1'
        local state = exports['qb-weathersync']:setDynamicWeather(enabled)
        TriggerEvent('qb-weathersync:server:RequestStateSync')
        notify(src, state and 'Dynamic weather enabled.' or 'Dynamic weather disabled.')

    elseif action == 'blackout' then
        local enabled = value == true or value == 'true' or value == 1 or value == '1'
        local state = exports['qb-weathersync']:setBlackout(enabled)
        TriggerEvent('qb-weathersync:server:RequestStateSync')
        notify(src, state and 'Blackout enabled.' or 'Blackout disabled.')

    elseif action == 'earthquake' then
        TriggerClientEvent('fadm:earthquake', -1, Config.EarthquakeDurationMs, Config.EarthquakeIntensity)
        notify(src, 'Earthquake initiated for all players.')
    end
end)

local restartSequenceActive = false

RegisterNetEvent('fadm:startRestartSequence', function()
    local src = source
    if not isAdmin(src) then return end

    if restartSequenceActive then
        notify(src, 'A restart sequence is already active.')
        return
    end

    restartSequenceActive = true

    CreateThread(function()
        local seconds = tonumber(Config.RestartWarningSeconds) or 120
        local storm = tostring(Config.RestartStormWeather or 'THUNDER')

        -- Disable dynamic weather so the warning storm is not replaced.
        if GetResourceState('qb-weathersync') == 'started' then
            exports['qb-weathersync']:setDynamicWeather(false)
            exports['qb-weathersync']:setWeather(storm)
            adminWorldState.weather = storm
            adminWorldState.active = true
            TriggerEvent('qb-weathersync:server:RequestStateSync')
            broadcastAdminWorldState()
        end

        TriggerClientEvent('fadm:restartWarningStart', -1, seconds)

        -- Send countdown milestones to the NUI/HUD.
        for remaining = seconds, 1, -1 do
            if remaining == 120 or remaining == 60 or remaining == 30 or remaining == 15 or remaining <= 10 then
                TriggerClientEvent('fadm:restartCountdown', -1, remaining)
            end
            Wait(1000)
        end

        TriggerClientEvent('fadm:restartNow', -1)
        Wait(1500)

        if Config.RestartUseQuitCommand then
            ExecuteCommand('quit "Server restarting - please reconnect shortly."')
        else
            print('^3[FiveM Admin]^7 Restart warning completed. Config.RestartUseQuitCommand is false, so FXServer was not stopped.')
            print('^3[FiveM Admin]^7 For a real txAdmin restart, schedule the restart in txAdmin; this resource can also react to txAdmin scheduled-restart events.')
            restartSequenceActive = false
        end
    end)
end)

-- If txAdmin itself has a scheduled restart, automatically start the storm/siren
-- when txAdmin reaches its official 2-minute warning.
AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if type(eventData) ~= 'table' or tonumber(eventData.secondsRemaining) ~= 120 then return end

    if GetResourceState('qb-weathersync') == 'started' then
        exports['qb-weathersync']:setDynamicWeather(false)
        exports['qb-weathersync']:setWeather(tostring(Config.RestartStormWeather or 'THUNDER'))
        TriggerEvent('qb-weathersync:server:RequestStateSync')
    end

    TriggerClientEvent('fadm:restartWarningStart', -1, 120)
end)




-- v19: Give Item
RegisterNetEvent('fadm:giveItem', function(target, itemName, amount)
    local src = source
    if not isAdmin(src) then return end

    target = tonumber(target)
    amount = math.floor(tonumber(amount) or 0)
    itemName = tostring(itemName or ''):lower():gsub('%s+', '')

    if not target or not GetPlayerName(target) then
        notify(src, 'Player is no longer online.')
        return
    end
    if itemName == '' or amount < 1 or amount > 1000 then
        notify(src, 'Invalid item or amount (1-1000).')
        return
    end

    local QBCore = exports['qb-core']:GetCoreObject()
    local Player = QBCore.Functions.GetPlayer(target)
    if not Player then
        notify(src, 'Could not find QBCore player.')
        return
    end

    local item = QBCore.Shared.Items[itemName]
    if not item then
        notify(src, ('Unknown item: %s'):format(itemName))
        return
    end

    local success = Player.Functions.AddItem(itemName, amount)
    if success == false then
        notify(src, 'Could not give item. Inventory may be full.')
        return
    end

    -- Standard qb-inventory item box notification when available.
    TriggerClientEvent('inventory:client:ItemBox', target, item, 'add', amount)
    notify(src, ('Gave %sx %s to %s.'):format(amount, item.label or itemName, GetPlayerName(target)))
    notify(target, ('You received %sx %s from an administrator.'):format(amount, item.label or itemName))
end)

-- v18: reliable admin teleport routing.
RegisterNetEvent('fadm:teleportAction', function(action, target)
    local src = source
    if not isAdmin(src) then return end

    target = tonumber(target)
    if not target or not GetPlayerName(target) then
        notify(src, 'Player is no longer online.')
        return
    end

    if action == 'goto' then
        -- The selected player's client sends its live coordinates back to the admin.
        TriggerClientEvent('fadm:sendMyCoordsForTeleport', target, src, 'goto')
    elseif action == 'bring' then
        -- The admin sends their live coordinates back for the selected player.
        TriggerClientEvent('fadm:sendMyCoordsForTeleport', src, target, 'bring')
    end
end)

RegisterNetEvent('fadm:teleportCoordsResponse', function(destination, mode, x, y, z, heading)
    local src = source
    destination = tonumber(destination)
    if not destination or not GetPlayerName(destination) then return end

    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    heading = tonumber(heading) or 0.0
    if not x or not y or not z then return end

    -- For Bring, only an admin may provide the destination coordinates.
    if mode == 'bring' and not isAdmin(src) then return end
    -- For Go To, the destination must be an admin.
    if mode == 'goto' and not isAdmin(destination) then return end

    TriggerClientEvent('fadm:teleportNow', destination, x, y, z, heading)
end)

RegisterNetEvent('fadm:manageMoney', function(target, account, operation, amount)
    local src=source
    if not isAdmin(src) then return end
    target=tonumber(target); amount=math.floor(tonumber(amount) or 0)
    account=tostring(account or ''):lower()
    operation=tostring(operation or ''):lower()
    if not target or not GetPlayerName(target) then notify(src,'Player is no longer online.') return end
    if account~='cash' and account~='bank' then notify(src,'Invalid money account.') return end
    if operation~='add' and operation~='remove' then notify(src,'Invalid money operation.') return end
    if amount<1 or amount>10000000 then notify(src,'Amount must be between $1 and $10,000,000.') return end
    local QBCore=exports['qb-core']:GetCoreObject()
    local Player=QBCore.Functions.GetPlayer(target)
    if not Player then notify(src,'Unable to load player data.') return end
    if operation=='remove' then
        local balance=tonumber(Player.PlayerData.money and Player.PlayerData.money[account]) or 0
        if balance<amount then notify(src,('Player only has $%s in %s.'):format(balance,account)) return end
        Player.Functions.RemoveMoney(account,amount,'fivem-admin')
    else
        Player.Functions.AddMoney(account,amount,'fivem-admin')
    end
    notify(src,('%s $%s %s %s.'):format(operation=='add' and 'Added' or 'Removed',amount,operation=='add' and 'to' or 'from',GetPlayerName(target)))
    TriggerClientEvent('QBCore:Notify',target,('$%s was %s your %s by an administrator.'):format(amount,operation=='add' and 'added to' or 'removed from',account),operation=='add' and 'success' or 'primary')
end)

RegisterNetEvent('fadm:kickPlayer', function(target, reason)
    local src=source
    if not isAdmin(src) then return end
    target=tonumber(target)
    if not target or not GetPlayerName(target) then notify(src,'Player is no longer online.') return end
    reason=tostring(reason or ''):gsub('^%s+',''):gsub('%s+$','')
    if reason=='' then reason='Removed by an administrator.' end
    if #reason>250 then reason=reason:sub(1,250) end
    local targetName=GetPlayerName(target)
    notify(src,('Kicked %s.'):format(targetName))
    DropPlayer(target,reason)
end)

RegisterNetEvent('fadm:requestFreshPlayerInfo', function(target, requestId)
    local src=source
    if not isAdmin(src) then return end
    target=tonumber(target)
    if not target or not GetPlayerName(target) then
        TriggerClientEvent('fadm:freshPlayerInfo',src,requestId,nil)
        return
    end
    local QBCore=exports['qb-core']:GetCoreObject()
    local Player=QBCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('fadm:freshPlayerInfo',src,requestId,nil)
        return
    end
    local pd=Player.PlayerData or {}
    local job=pd.job or {}
    local grade=job.grade or {}
    local money=pd.money or {}
    TriggerClientEvent('fadm:freshPlayerInfo',src,requestId,{
        id=target,
        citizenid=pd.citizenid or 'N/A',
        jobName=job.name or 'unemployed',
        jobLabel=job.label or job.name or 'Unemployed',
        jobGrade=tonumber(grade.level or grade) or 0,
        jobGradeName=grade.name or '',
        gang=(pd.gang and (pd.gang.label or pd.gang.name)) or 'None',
        cash=tonumber(money.cash) or 0,
        bank=tonumber(money.bank) or 0
    })
end)
