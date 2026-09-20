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
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        list[#list + 1] = {
            id = src,
            name = GetPlayerName(src) or ('Player ' .. src)
        }
    end
    table.sort(list, function(a,b) return a.id < b.id end)
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
