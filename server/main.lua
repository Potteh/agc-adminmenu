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

    elseif action == 'spectate' then
        TriggerClientEvent('fadm:spectate', src, target)
    else
        notify(src, 'Unknown action.')
    end
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
