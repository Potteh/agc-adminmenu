local menuOpen = false
local spectating = false
local spectateTarget = nil

local function setMenu(state)
    menuOpen = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = state and 'show' or 'hide' })
end

RegisterNetEvent('fadm:open', function()
    TriggerServerEvent('fadm:getData')
end)

RegisterNetEvent('fadm:openData', function(data)
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show', data = data })
end)

RegisterNetEvent('fadm:updateData', function(data)
    SendNUIMessage({ action = 'data', data = data })
end)

RegisterNetEvent('fadm:newReport', function(report)
    SendNUIMessage({ action = 'newReport', report = report })
end)

RegisterNetEvent('fadm:notify', function(msg)
    SendNUIMessage({ action = 'toast', message = msg })
end)

RegisterNetEvent('fadm:reportReply', function(data)
    local msg = ('Admin reply to report #%s: %s'):format(data.reportId or '?', data.message or '')
    SendNUIMessage({
        action = 'reportReplyNotification',
        message = msg,
        reportId = data.reportId,
        admin = data.admin
    })

    -- Native GTA notification as a fallback if the admin menu is closed.
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end)

RegisterNetEvent('fadm:setFreeze', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
end)

RegisterNetEvent('fadm:setFire', function(duration)
    local ped = PlayerPedId()
    StartEntityFire(ped)
    SetTimeout(duration or 5000, function()
        StopEntityFire(ped)
    end)
end)

RegisterNetEvent('fadm:kill', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 0)
end)

RegisterNetEvent('fadm:explodeVehicle', function()
    local ped = PlayerPedId()

    if not IsPedInAnyVehicle(ped, false) then
        TriggerEvent('fadm:notify', 'You are not currently in a vehicle.')
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    local coords = GetEntityCoords(vehicle)
    NetworkRequestControlOfEntity(vehicle)

    local timeout = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(vehicle)
    end

    SetVehicleEngineHealth(vehicle, -4000.0)
    SetVehiclePetrolTankHealth(vehicle, -4000.0)
    ExplodeVehicle(vehicle, true, false)
    AddExplosion(coords.x, coords.y, coords.z, 2, 1.0, true, false, 1.0)
end)

RegisterNetEvent('fadm:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end)

RegisterNetEvent('fadm:heal', function()
    local ped = PlayerPedId()
    ClearPedBloodDamage(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end)

RegisterNetEvent('fadm:wildDogs', function(count)
    local targetPed = PlayerPedId()
    local model = joaat('a_c_rottweiler')
    count = math.max(1, math.min(tonumber(count) or 4, 8))

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then return end

    local c = GetEntityCoords(targetPed)
    for i = 1, count do
        local angle = (math.pi * 2 / count) * i
        local radius = 7.0 + math.random() * 4.0
        local dog = CreatePed(28, model,
            c.x + math.cos(angle) * radius,
            c.y + math.sin(angle) * radius,
            c.z + 1.0, 0.0, true, true)

        if DoesEntityExist(dog) then
            SetEntityAsMissionEntity(dog, true, true)
            SetPedFleeAttributes(dog, 0, false)
            SetPedCombatAttributes(dog, 5, true)
            SetPedCombatAttributes(dog, 46, true)
            SetPedCombatAbility(dog, 2)
            SetPedCombatRange(dog, 2)
            SetPedSeeingRange(dog, 100.0)
            SetPedHearingRange(dog, 100.0)
            SetPedKeepTask(dog, true)
            TaskCombatPed(dog, targetPed, 0, 16)

            SetTimeout(120000, function()
                if DoesEntityExist(dog) then DeleteEntity(dog) end
            end)
        end
    end
    SetModelAsNoLongerNeeded(model)
end)


RegisterNetEvent('fadm:spawnVehicle', function(modelName)
    modelName = tostring(modelName or ''):lower():gsub('%s+', '')
    if modelName == '' or #modelName > 50 then
        TriggerEvent('fadm:notify', 'Invalid vehicle model.')
        return
    end

    local model = joaat(modelName)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        TriggerEvent('fadm:notify', ('Vehicle model "%s" was not found.'):format(modelName))
        return
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then
        TriggerEvent('fadm:notify', 'Vehicle model failed to load.')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
    if DoesEntityExist(vehicle) then
        SetVehicleOnGroundProperly(vehicle)
        SetPedIntoVehicle(ped, vehicle, -1)

    -- Give the admin keys using qb-vehiclekeys.
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)

        SetVehicleEngineOn(vehicle, true, true, false)
        TriggerEvent('fadm:notify', ('Spawned %s.'):format(modelName))
    end
    SetModelAsNoLongerNeeded(model)
end)

RegisterNetEvent('fadm:spectate', function(target)
    if spectating then return end

    local targetPed = GetPlayerPed(GetPlayerFromServerId(target))
    if not DoesEntityExist(targetPed) then
        TriggerEvent('fadm:notify', 'Target is no longer available.')
        return
    end

    spectating = true
    spectateTarget = target
    local myPed = PlayerPedId()

    SetEntityVisible(myPed, false, false)
    SetEntityInvincible(myPed, true)
    FreezeEntityPosition(myPed, true)
    SetEntityCollision(myPed, false, false)

    NetworkSetInSpectatorMode(true, targetPed)
    SendNUIMessage({ action = 'spectating', target = target })
end)

local function stopSpectate()
    if not spectating then return end

    NetworkSetInSpectatorMode(false, 0)
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)

    spectating = false
    spectateTarget = nil
    SendNUIMessage({ action = 'spectateOff' })
end

RegisterNUICallback('close', function(_, cb)
    setMenu(false)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('fadm:refresh')
    cb({ ok = true })
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    TriggerServerEvent('fadm:spawnVehicleRequest', data.model)
    cb({ ok = true })
end)

RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('fadm:action', data.action, tonumber(data.target), data.reason)
    cb({ ok = true })
end)

RegisterNUICallback('closeReport', function(data, cb)
    TriggerServerEvent('fadm:closeReport', tonumber(data.id))
    cb({ ok = true })
end)

RegisterNUICallback('replyReport', function(data, cb)
    TriggerServerEvent('fadm:replyReport', tonumber(data.id), data.message)
    cb({ ok = true })
end)

RegisterNUICallback('stopSpectate', function(_, cb)
    stopSpectate()
    cb({ ok = true })
end)

RegisterKeyMapping('admin', 'Open FiveM Admin Menu', 'keyboard', 'F10')

CreateThread(function()
    while true do
        Wait(0)
        if spectating and IsControlJustPressed(0, 322) then -- ESC
            stopSpectate()
        end
    end
end)

-- Player report command fallback:
-- /report [player id] [message]
RegisterCommand('report', function(_, args)
    local target = tonumber(args[1])
    table.remove(args, 1)
    local message = table.concat(args, ' ')
    if not target or message == '' then
        TriggerEvent('fadm:notify', 'Usage: /report [player id] [message]')
        return
    end
    TriggerServerEvent('fadm:submitReport', target, message)
end, false)

RegisterNUICallback('submitReport', function(data, cb)
    TriggerServerEvent('fadm:submitReport', tonumber(data.target), data.message)
    cb({ ok = true })
end)


RegisterNetEvent('fadm:earthquake', function(duration, intensity)
    duration = tonumber(duration) or 15000
    intensity = math.min(tonumber(intensity) or 0.18, 0.25)

    CreateThread(function()
        local finish = GetGameTimer() + duration
        local nextRagdoll = GetGameTimer() + math.random(1000, 2500)

        -- Start one gentle continuous shake instead of repeatedly stacking
        -- LARGE_EXPLOSION_SHAKE every few hundred milliseconds.
        ShakeGameplayCam('ROAD_VIBRATION_SHAKE', intensity)

        while GetGameTimer() < finish do
            local ped = PlayerPedId()
            local now = GetGameTimer()

            if now >= nextRagdoll
                and DoesEntityExist(ped)
                and not IsEntityDead(ped)
                and not IsPedInAnyVehicle(ped, false)
                and not IsPedFalling(ped)
                and not IsPedRagdoll(ped) then

                if math.random(100) <= 35 then
                    SetPedToRagdoll(ped, 900, 1400, 0, false, false, false)
                end
                nextRagdoll = now + math.random(2200, 4000)
            end

            Wait(200)
        end

        StopGameplayCamShaking(true)
    end)
end)

RegisterNUICallback('worldAction', function(data, cb)
    TriggerServerEvent('fadm:worldAction', data.action, data.value)
    cb({ok=true})
end)

local restartSirenId = nil

RegisterNetEvent('fadm:restartWarningStart', function(seconds)
    seconds = tonumber(seconds) or 120

    SendNUIMessage({
        action = 'restartWarning',
        seconds = seconds,
        message = 'SEVERE THUNDERSTORM - SERVER RESTART'
    })

    -- Keep repeating the warning siren for the entire restart countdown.
    -- The frontend sound itself is not reliably looped by GTA, so restart it
    -- periodically until the countdown expires.
    if restartSirenId then
        StopSound(restartSirenId)
        ReleaseSoundId(restartSirenId)
        restartSirenId = nil
    end

    CreateThread(function()
        local finish = GetGameTimer() + (seconds * 1000)

        while GetGameTimer() < finish do
            if restartSirenId then
                StopSound(restartSirenId)
                ReleaseSoundId(restartSirenId)
            end

            restartSirenId = GetSoundId()
            PlaySoundFrontend(
                restartSirenId,
                Config.RestartSirenSoundName or 'Air_Defences_Activated',
                Config.RestartSirenSoundSet or 'DLC_sum20_Business_Battle_AC_Sounds',
                true
            )

            -- Replay before/around the point where this GTA sound normally ends.
            local replayAt = GetGameTimer() + 10000
            while GetGameTimer() < replayAt and GetGameTimer() < finish do
                Wait(250)
            end
        end

        if restartSirenId then
            StopSound(restartSirenId)
            ReleaseSoundId(restartSirenId)
            restartSirenId = nil
        end
    end)
end)

RegisterNetEvent('fadm:restartCountdown', function(seconds)
    SendNUIMessage({ action = 'restartCountdown', seconds = tonumber(seconds) or 0 })
end)

RegisterNetEvent('fadm:restartNow', function()
    if restartSirenId then
        StopSound(restartSirenId)
        ReleaseSoundId(restartSirenId)
        restartSirenId = nil
    end
    SendNUIMessage({ action = 'restartNow' })
end)

RegisterNUICallback('startRestartSequence', function(_, cb)
    TriggerServerEvent('fadm:startRestartSequence')
    cb({ok=true})
end)

local fadmWorldState = nil

RegisterNetEvent('fadm:syncAdminWorldState', function(state)
    if type(state) == 'table' then fadmWorldState = state end
end)

CreateThread(function()
    while true do
        if fadmWorldState and fadmWorldState.active then
            if fadmWorldState.weather then
                local w = tostring(fadmWorldState.weather)
                ClearOverrideWeather()
                ClearWeatherTypePersist()
                SetWeatherTypePersist(w)
                SetWeatherTypeNow(w)
                SetWeatherTypeNowPersist(w)
                if w == 'RAIN' then SetRainLevel(0.3)
                elseif w == 'THUNDER' then SetRainLevel(0.5)
                else SetRainLevel(0.0) end
            end
            if fadmWorldState.hour ~= nil then
                NetworkOverrideClockTime(tonumber(fadmWorldState.hour) or 12, tonumber(fadmWorldState.minute) or 0, 0)
            end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)


-- v18 teleport implementation.
RegisterNetEvent('fadm:sendMyCoordsForTeleport', function(destination, mode)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent(
        'fadm:teleportCoordsResponse',
        tonumber(destination),
        tostring(mode),
        coords.x, coords.y, coords.z,
        GetEntityHeading(ped)
    )
end)

RegisterNetEvent('fadm:teleportNow', function(x, y, z, heading)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end

    local ped = PlayerPedId()
    local entity = ped
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            entity = veh
        end
    end

    DoScreenFadeOut(200)
    local timeout = GetGameTimer() + 1000
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end

    RequestCollisionAtCoord(x, y, z)
    FreezeEntityPosition(entity, true)
    SetEntityCoordsNoOffset(entity, x, y, z + 0.5, false, false, false)
    SetEntityHeading(entity, tonumber(heading) or GetEntityHeading(entity))
    Wait(250)
    FreezeEntityPosition(entity, false)

    DoScreenFadeIn(200)
end)

RegisterNUICallback('teleportAction', function(data, cb)
    local action = tostring(data.action or '')
    local target = tonumber(data.target)
    if (action == 'goto' or action == 'bring') and target then
        TriggerServerEvent('fadm:teleportAction', action, target)
    end
    cb({ ok = true })
end)


RegisterNUICallback('giveItem', function(data, cb)
    TriggerServerEvent('fadm:giveItem', tonumber(data.target), tostring(data.item or ''), tonumber(data.amount) or 1)
    cb({ ok = true })
end)
