local menuOpen = false
local spectating = false
local spectateTarget = nil
local spectateReturn = nil

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

        -- Give the admin keys, then register the spawned vehicle as owned.
        local plate = GetVehicleNumberPlateText(vehicle)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)

        local props = {}
        local QBCore = exports['qb-core']:GetCoreObject()
        if QBCore and QBCore.Functions and QBCore.Functions.GetVehicleProperties then
            props = QBCore.Functions.GetVehicleProperties(vehicle) or {}
        end

        TriggerServerEvent('fadm:registerSpawnedVehicle', modelName, plate, props)
        SetVehicleEngineOn(vehicle, true, true, false)
        TriggerEvent('fadm:notify', ('Spawned %s and registered it as your owned vehicle.'):format(modelName))
    end
    SetModelAsNoLongerNeeded(model)
end)

local function beginSpectate(target)
 local player=GetPlayerFromServerId(tonumber(target));if player==-1 then TriggerEvent('fadm:notify','Target is no longer available.');return end
 local tp=GetPlayerPed(player);if not DoesEntityExist(tp) then return end
 local ped=PlayerPedId()
 if not spectating then local v=GetEntityCoords(ped);spectateReturn={x=v.x,y=v.y,z=v.z,h=GetEntityHeading(ped)} else NetworkSetInSpectatorMode(false,0) end
 spectating=true;spectateTarget=tonumber(target);SetEntityVisible(ped,false,false);SetEntityInvincible(ped,true);FreezeEntityPosition(ped,true);SetEntityCollision(ped,false,false)
 NetworkSetInSpectatorMode(true,tp);SendNUIMessage({action='spectating',target=spectateTarget,name=GetPlayerName(player) or ('ID '..spectateTarget)})
end
RegisterNetEvent('fadm:spectate',function(target) beginSpectate(target) end)
local function stopSpectate()
 if not spectating then return end
 NetworkSetInSpectatorMode(false,0);local ped=PlayerPedId();SetEntityVisible(ped,true,false);SetEntityInvincible(ped,false);FreezeEntityPosition(ped,false);SetEntityCollision(ped,true,true)
 if spectateReturn then SetEntityCoordsNoOffset(ped,spectateReturn.x,spectateReturn.y,spectateReturn.z,false,false,false);SetEntityHeading(ped,spectateReturn.h or 0.0) end
 spectating=false;spectateTarget=nil;spectateReturn=nil;SendNUIMessage({action='spectateOff'})
end
local function cycleSpectate(dir)
 local ids={};for _,p in ipairs(GetActivePlayers()) do local id=GetPlayerServerId(p);if id~=GetPlayerServerId(PlayerId()) then ids[#ids+1]=id end end
 table.sort(ids);if #ids==0 then return end;local idx=1;for i,id in ipairs(ids) do if id==spectateTarget then idx=i break end end
 idx=((idx-1+dir)%#ids)+1;beginSpectate(ids[idx])
end
RegisterNUICallback('spectateCycle',function(data,cb) cycleSpectate(tonumber(data.dir) or 1);cb({ok=true}) end)

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
RegisterCommand('report', function()
    -- Player-facing report UI. This does not request admin data or require admin duty.
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openReportForm' })
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


RegisterNUICallback('transferVehicle', function(data, cb)
    local target = tonumber(data.target)
    local ped = PlayerPedId()

    if not target then
        TriggerEvent('fadm:notify', 'Invalid target player.')
        cb({ ok = false })
        return
    end

    if not IsPedInAnyVehicle(ped, false) then
        TriggerEvent('fadm:notify', 'You must be sitting in the vehicle you want to transfer.')
        cb({ ok = false })
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        cb({ ok = false })
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerServerEvent('fadm:transferVehicle', target, plate)
    cb({ ok = true })
end)

RegisterNetEvent('fadm:receiveTransferredVehicleKeys', function(plate)
    TriggerEvent('vehiclekeys:client:SetOwner', tostring(plate or ''))
end)


local fadmSavedClothes = nil

RegisterNetEvent('fadm:stripClothes', function()
    local ped = PlayerPedId()

    -- Save the affected components once so Restore Clothes can put them back.
    fadmSavedClothes = {
        [3]  = { GetPedDrawableVariation(ped, 3),  GetPedTextureVariation(ped, 3),  GetPedPaletteVariation(ped, 3)  },
        [4]  = { GetPedDrawableVariation(ped, 4),  GetPedTextureVariation(ped, 4),  GetPedPaletteVariation(ped, 4)  },
        [6]  = { GetPedDrawableVariation(ped, 6),  GetPedTextureVariation(ped, 6),  GetPedPaletteVariation(ped, 6)  },
        [8]  = { GetPedDrawableVariation(ped, 8),  GetPedTextureVariation(ped, 8),  GetPedPaletteVariation(ped, 8)  },
        [11] = { GetPedDrawableVariation(ped, 11), GetPedTextureVariation(ped, 11), GetPedPaletteVariation(ped, 11) }
    }

    -- Freemode component slots:
    -- 3 arms/torso, 4 legs, 6 shoes, 8 undershirt, 11 tops.
    -- These are GTA clothing-component changes only; no custom nude model is used.
    SetPedComponentVariation(ped, 11, 15, 0, 0) -- top
    SetPedComponentVariation(ped, 8, 15, 0, 0)  -- undershirt
    SetPedComponentVariation(ped, 3, 15, 0, 0)  -- torso/arms
    SetPedComponentVariation(ped, 4, 14, 0, 0)  -- pants/underwear-style freemode component
    SetPedComponentVariation(ped, 6, 34, 0, 0)  -- barefoot-style freemode component
end)

RegisterNetEvent('fadm:restoreClothes', function()
    local ped = PlayerPedId()
    if not fadmSavedClothes then return end

    for component, data in pairs(fadmSavedClothes) do
        SetPedComponentVariation(ped, component, data[1], data[2], data[3])
    end
    fadmSavedClothes = nil
end)

RegisterNUICallback('setPlayerJob', function(data, cb)
    TriggerServerEvent('fadm:setPlayerJob', tonumber(data.target), tostring(data.job or ''), tonumber(data.grade) or 0)
    cb({ok=true})
end)

RegisterNUICallback('getCoords', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    cb({
        ok = true,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading
    })
end)


RegisterNetEvent('fadm:requestWaypointCoords', function(adminSrc)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('fadm:waypointCoordsResponse', tonumber(adminSrc), coords.x, coords.y, coords.z)
end)

RegisterNetEvent('fadm:setWaypointCoords', function(x, y, z, playerName)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end
    SetNewWaypoint(x + 0.0, y + 0.0)
    TriggerEvent('fadm:notify', ('Waypoint set to %s.'):format(tostring(playerName or 'player')))
end)

RegisterNUICallback('waypointPlayer', function(data, cb)
    local target = tonumber(data.target)
    if target then
        TriggerServerEvent('fadm:waypointToPlayer', target)
    end
    cb({ok = target ~= nil})
end)


RegisterNetEvent('fadm:ragdollPlayer', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, vehicle, 4160)
        Wait(500)
    end
    SetPedToRagdoll(ped, 5000, 5000, 0, false, false, false)
end)

local fadmGodMode = false

RegisterNUICallback('toggleGodMode', function(_, cb)
    fadmGodMode = not fadmGodMode
    local ped = PlayerPedId()
    SetEntityInvincible(ped, fadmGodMode)
    SetPlayerInvincible(PlayerId(), fadmGodMode)
    SetPedCanRagdoll(ped, not fadmGodMode)

    if fadmGodMode then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    end

    cb({ok=true, enabled=fadmGodMode})
end)

-- Re-apply invincibility because ped replacement/respawn can reset native flags.
CreateThread(function()
    while true do
        Wait(1000)
        if fadmGodMode then
            local ped = PlayerPedId()
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(PlayerId(), true)
            SetPedCanRagdoll(ped, false)
        end
    end
end)

local fadmNoclip=false
local fadmInvisible=false
RegisterNUICallback('toggleNoclip',function(_,cb)
 fadmNoclip=not fadmNoclip local ped=PlayerPedId()
 FreezeEntityPosition(ped,fadmNoclip) SetEntityCollision(ped,not fadmNoclip,not fadmNoclip)
 cb({ok=true,enabled=fadmNoclip})
end)
CreateThread(function()
 while true do
  if not fadmNoclip then Wait(400) else
   Wait(0) local ped=PlayerPedId() local pos=GetEntityCoords(ped) local rot=GetGameplayCamRot(2)
   local rz=math.rad(rot.z) local rx=math.rad(rot.x)
   local dir=vector3(-math.sin(rz)*math.abs(math.cos(rx)),math.cos(rz)*math.abs(math.cos(rx)),math.sin(rx))
   local right=vector3(math.cos(rz),math.sin(rz),0.0) local speed=IsControlPressed(0,21) and 2.5 or 0.7
   if IsControlPressed(0,32) then pos=pos+dir*speed end
   if IsControlPressed(0,33) then pos=pos-dir*speed end
   if IsControlPressed(0,34) then pos=pos-right*speed end
   if IsControlPressed(0,35) then pos=pos+right*speed end
   if IsControlPressed(0,22) then pos=pos+vector3(0,0,speed) end
   if IsControlPressed(0,36) then pos=pos-vector3(0,0,speed) end
   SetEntityCoordsNoOffset(ped,pos.x,pos.y,pos.z,true,true,true) SetEntityHeading(ped,rot.z)
  end
 end
end)
RegisterNUICallback('toggleInvisible',function(_,cb)
 fadmInvisible=not fadmInvisible local ped=PlayerPedId()
 SetEntityVisible(ped,not fadmInvisible,false) SetEntityAlpha(ped,fadmInvisible and 0 or 255,false)
 cb({ok=true,enabled=fadmInvisible})
end)
RegisterNUICallback('teleportWaypoint',function(_,cb)
 local blip=GetFirstBlipInfoId(8)
 if not DoesBlipExist(blip) then cb({ok=false,message='Place a waypoint on the map first.'}) return end
 local c=GetBlipInfoIdCoord(blip) local ped=PlayerPedId() local found=false
 for height=1000,0,-25 do
  SetEntityCoordsNoOffset(ped,c.x,c.y,height+0.0,false,false,false) Wait(10)
  local ok,z=GetGroundZFor_3dCoord(c.x,c.y,height+0.0,false)
  if ok then SetEntityCoordsNoOffset(ped,c.x,c.y,z+1.0,false,false,false) found=true break end
 end
 if not found then SetEntityCoordsNoOffset(ped,c.x,c.y,100.0,false,false,false) end
 cb({ok=true})
end)
local function fadmRotDir(r)
 local rz=math.rad(r.z) local rx=math.rad(r.x) local cx=math.abs(math.cos(rx))
 return vector3(-math.sin(rz)*cx,math.cos(rz)*cx,math.sin(rx))
end
RegisterNUICallback('inspectEntity',function(_,cb)
 local cam=GetGameplayCamCoord() local dest=cam+fadmRotDir(GetGameplayCamRot(2))*25.0
 local ray=StartShapeTestRay(cam.x,cam.y,cam.z,dest.x,dest.y,dest.z,-1,PlayerPedId(),7)
 local _,hit,_,_,entity=GetShapeTestResult(ray)
 if hit~=1 or entity==0 then cb({ok=false,message='No entity found in front of you.'}) return end
 local c=GetEntityCoords(entity) local t=GetEntityType(entity)
 cb({ok=true,type=t==1 and 'Ped' or t==2 and 'Vehicle' or t==3 and 'Object' or 'Unknown',entity=entity,
 networkId=NetworkGetNetworkIdFromEntity(entity),model=GetEntityModel(entity),x=c.x,y=c.y,z=c.z,
 heading=GetEntityHeading(entity),health=GetEntityHealth(entity)})
end)

RegisterNUICallback('getPlayerLiveInfo',function(data,cb)
 local sid=tonumber(data and data.id); if not sid then cb({ok=false}) return end
 local player=GetPlayerFromServerId(sid); if player==-1 then cb({ok=false,message='Player is not currently streamed to you.'}) return end
 local ped=GetPlayerPed(player); if not DoesEntityExist(ped) then cb({ok=false,message='Player entity unavailable.'}) return end
 local pos=GetEntityCoords(ped); local veh=GetVehiclePedIsIn(ped,false); local vd=nil
 if veh~=0 then vd={model=GetEntityModel(veh),plate=GetVehicleNumberPlateText(veh),engine=GetVehicleEngineHealth(veh),body=GetVehicleBodyHealth(veh),speed=GetEntitySpeed(veh)*2.236936} end
 cb({ok=true,health=GetEntityHealth(ped),maxHealth=GetEntityMaxHealth(ped),armor=GetPedArmour(ped),x=pos.x,y=pos.y,z=pos.z,heading=GetEntityHeading(ped),vehicle=vd})
end)

RegisterNUICallback('manageMoney',function(data,cb)
 TriggerServerEvent('fadm:manageMoney',data.target,data.account,data.operation,data.amount)
 cb({ok=true})
end)
RegisterNUICallback('kickPlayer',function(data,cb)
 TriggerServerEvent('fadm:kickPlayer',data.target,data.reason)
 cb({ok=true})
end)

local fadmFreshInfoRequests={}
local fadmFreshInfoCounter=0

RegisterNUICallback('getFreshPlayerInfo',function(data,cb)
 fadmFreshInfoCounter=fadmFreshInfoCounter+1
 local requestId=tostring(GetGameTimer())..':'..tostring(fadmFreshInfoCounter)
 fadmFreshInfoRequests[requestId]=cb
 TriggerServerEvent('fadm:requestFreshPlayerInfo',data.id,requestId)
 SetTimeout(3000,function()
  if fadmFreshInfoRequests[requestId] then
   fadmFreshInfoRequests[requestId]({ok=false,message='Timed out refreshing server player data.'})
   fadmFreshInfoRequests[requestId]=nil
  end
 end)
end)

RegisterNetEvent('fadm:freshPlayerInfo',function(requestId,data)
 local cb=fadmFreshInfoRequests[tostring(requestId)]
 if not cb then return end
 fadmFreshInfoRequests[tostring(requestId)]=nil
 if not data then cb({ok=false,message='Unable to refresh player data.'}) return end
 data.ok=true
 cb(data)
end)

local fadmVehicleRequests={}
local fadmVehicleCounter=0
RegisterNUICallback('getOwnedVehicles',function(data,cb)
 fadmVehicleCounter=fadmVehicleCounter+1
 local rid=tostring(GetGameTimer())..':veh:'..tostring(fadmVehicleCounter)
 fadmVehicleRequests[rid]=cb
 TriggerServerEvent('fadm:requestOwnedVehicles',data.target,rid)
 SetTimeout(4000,function()
  if fadmVehicleRequests[rid] then fadmVehicleRequests[rid]({ok=false,vehicles={}}) fadmVehicleRequests[rid]=nil end
 end)
end)
RegisterNetEvent('fadm:ownedVehiclesResponse',function(rid,rows)
 local cb=fadmVehicleRequests[tostring(rid)];if not cb then return end
 fadmVehicleRequests[tostring(rid)]=nil
 cb({ok=true,vehicles=rows or {}})
end)
RegisterNUICallback('setVehicleGarage',function(data,cb)
 TriggerServerEvent('fadm:setVehicleGarage',data.target,data.plate,data.garage)
 cb({ok=true})
end)

local fadmAdminLogCb=nil
RegisterNUICallback('getAdminLogs',function(_,cb) fadmAdminLogCb=cb;TriggerServerEvent('fadm:requestAdminLogs');SetTimeout(3000,function() if fadmAdminLogCb then fadmAdminLogCb({ok=false,logs={}});fadmAdminLogCb=nil end end) end)
RegisterNetEvent('fadm:adminLogsResponse',function(rows) if fadmAdminLogCb then fadmAdminLogCb({ok=true,logs=rows or {}});fadmAdminLogCb=nil end end)

RegisterNUICallback('auditAction', function(data, cb)
    TriggerServerEvent('fadm:recordAdminAction', data.target, data.action, data.details)
    cb({ok=true})
end)

RegisterNetEvent('fadm:vehicleManageClient',function(action)
 local ped=PlayerPedId()
 local veh=GetVehiclePedIsIn(ped,false)
 if veh==0 then
  TriggerEvent('QBCore:Notify','You must be inside a vehicle for this admin vehicle action.','error')
  return
 end
 if action=='repair' then
  SetVehicleFixed(veh);SetVehicleDeformationFixed(veh);SetVehicleEngineHealth(veh,1000.0);SetVehicleBodyHealth(veh,1000.0)
 elseif action=='clean' then
  SetVehicleDirtLevel(veh,0.0);WashDecalsFromVehicle(veh,1.0)
 elseif action=='refuel' then
  SetVehicleFuelLevel(veh,100.0)
  pcall(function() exports['qb-fuel']:SetFuel(veh,100.0) end)
 elseif action=='flip' then
  local h=GetEntityHeading(veh);SetEntityRotation(veh,0.0,0.0,h,2,true);SetVehicleOnGroundProperly(veh)
 elseif action=='unlock' then
  SetVehicleDoorsLocked(veh,1);SetVehicleDoorsLockedForAllPlayers(veh,false)
 elseif action=='delete' then
  NetworkRequestControlOfEntity(veh)
  local untilTime=GetGameTimer()+1500
  while not NetworkHasControlOfEntity(veh) and GetGameTimer()<untilTime do Wait(0);NetworkRequestControlOfEntity(veh) end
  SetEntityAsMissionEntity(veh,true,true);DeleteVehicle(veh)
 elseif action=='maxmods' then
  SetVehicleModKit(veh,0)
  for modType=0,49 do
   local count=GetNumVehicleMods(veh,modType)
   if count>0 then SetVehicleMod(veh,modType,count-1,false) end
  end
  ToggleVehicleMod(veh,18,true);ToggleVehicleMod(veh,20,true);ToggleVehicleMod(veh,22,true)
 end
end)

RegisterNUICallback('vehicleManage',function(data,cb)
 TriggerServerEvent('fadm:vehicleManage',data.target,data.action)
 cb({ok=true})
end)


local fadmWarningRequests={}
local fadmWarningCounter=0
RegisterNUICallback('getWarnings',function(data,cb)
 fadmWarningCounter=fadmWarningCounter+1;local rid=tostring(GetGameTimer())..':warn:'..fadmWarningCounter;fadmWarningRequests[rid]=cb
 TriggerServerEvent('fadm:requestWarnings',data.target,rid)
 SetTimeout(3000,function() if fadmWarningRequests[rid] then fadmWarningRequests[rid]({ok=false,warnings={}});fadmWarningRequests[rid]=nil end end)
end)
RegisterNetEvent('fadm:warningsResponse',function(rid,rows) local cb=fadmWarningRequests[tostring(rid)];if cb then fadmWarningRequests[tostring(rid)]=nil;cb({ok=true,warnings=rows or {}}) end end)
RegisterNUICallback('issueWarning',function(data,cb) TriggerServerEvent('fadm:issueWarning',data.target,data.reason);cb({ok=true}) end)
RegisterNUICallback('toggleAdminDuty',function(_,cb) TriggerServerEvent('fadm:toggleDuty');fadmDutyCb=cb;SetTimeout(2000,function() if fadmDutyCb then fadmDutyCb({ok=false});fadmDutyCb=nil end end) end)
fadmDutyCb=nil
RegisterNetEvent('fadm:dutyState',function(state) if fadmDutyCb then fadmDutyCb({ok=true,onDuty=state});fadmDutyCb=nil end;SendNUIMessage({action='dutyState',onDuty=state}) end)
RegisterNetEvent('fadm:warningReceived',function(reason,adminName)
 local msg=('ADMIN WARNING: %s'):format(reason or 'No reason provided.')
 BeginTextCommandThefeedPost('STRING');AddTextComponentSubstringPlayerName(msg);EndTextCommandThefeedPostTicker(false,true)
 TriggerEvent('fadm:notify',msg)
end)


RegisterNetEvent('fadm:announcement',function(data)
 SendNUIMessage({action='serverAnnouncement',data=data})
end)
RegisterNetEvent('fadm:dutyRoster',function(roster)
 SendNUIMessage({action='dutyRoster',roster=roster})
end)
RegisterNUICallback('sendAnnouncement',function(data,cb)
 TriggerServerEvent('fadm:sendAnnouncement',data.kind,data.message);cb({ok=true})
end)
RegisterNUICallback('getDutyRoster',function(_,cb)
 TriggerServerEvent('fadm:requestDutyRoster');cb({ok=true})
end)

RegisterNUICallback('getBans',function(_,cb) TriggerServerEvent('fadm:requestBans');cb({ok=true}) end)
RegisterNUICallback('unban',function(data,cb) TriggerServerEvent('fadm:unban',data.id);cb({ok=true}) end)
RegisterNetEvent('fadm:bansData',function(rows) SendNUIMessage({action='bansData',bans=rows}) end)
RegisterNUICallback('claimReport',function(data,cb) TriggerServerEvent('fadm:claimReport',tonumber(data.id));cb({ok=true}) end)
RegisterNUICallback('unclaimReport',function(data,cb) TriggerServerEvent('fadm:unclaimReport',tonumber(data.id));cb({ok=true}) end)

RegisterNUICallback('getVehicleCatalog',function(_,cb) TriggerServerEvent('fadm:requestVehicleCatalog');cb({ok=true}) end)
RegisterNUICallback('getJobCatalog',function(_,cb) TriggerServerEvent('fadm:requestJobCatalog');cb({ok=true}) end)
RegisterNetEvent('fadm:vehicleCatalog',function(rows) SendNUIMessage({action='vehicleCatalog',vehicles=rows}) end)
RegisterNetEvent('fadm:jobCatalog',function(rows) SendNUIMessage({action='jobCatalog',jobs=rows}) end)
