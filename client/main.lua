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

RegisterNUICallback('action', function(data, cb)
    TriggerServerEvent('fadm:action', data.action, tonumber(data.target), data.reason)
    cb({ ok = true })
end)

RegisterNUICallback('closeReport', function(data, cb)
    TriggerServerEvent('fadm:closeReport', tonumber(data.id))
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
