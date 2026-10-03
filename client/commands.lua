-- Client side of the admin / dev commands registered in server/commands.lua

local function copy(text)
    SendNUIMessage({ action = 'copy', data = text })
    Arca.Notify({ title = 'Copied to clipboard', description = text, type = 'success' })
end

local function fmt(n) return ('%.2f'):format(n) end

---------------------------------------------------------------------
-- /fix
---------------------------------------------------------------------
RegisterNetEvent('arca_core:client:fixVehicle', function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return Arca.Notify('You are not in a vehicle', 'error') end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
    Arca.Notify('Vehicle repaired', 'success')
end)

---------------------------------------------------------------------
-- Teleporting
---------------------------------------------------------------------
---Moves the player (and their vehicle) to x, y and finds the ground if z is unknown
local function teleport(x, y, z, findGround)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local entity = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    FreezeEntityPosition(entity, true)

    if findGround then
        -- probe from the sky down until the map has loaded the ground under us
        local found = false
        for height = 1000.0, 0.0, -25.0 do
            SetEntityCoordsNoOffset(entity, x, y, height, false, false, false)
            RequestCollisionAtCoord(x, y, height)
            Wait(30)
            local ok, groundZ = GetGroundZFor_3dCoord(x, y, height, false)
            if ok then
                z, found = groundZ + 1.0, true
                break
            end
        end
        if not found then z = 100.0 end
    end

    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(entity) and GetGameTimer() < timeout do Wait(0) end

    FreezeEntityPosition(entity, false)
    DoScreenFadeIn(400)
end

RegisterNetEvent('arca_core:client:tpm', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return Arca.Notify('Set a waypoint on the map first', 'error') end
    local c = GetBlipInfoIdCoord(blip)
    teleport(c.x, c.y, nil, true)
    Arca.Notify('Teleported to waypoint', 'success')
end)

RegisterNetEvent('arca_core:client:teleport', function(coords)
    teleport(coords.x, coords.y, coords.z, false)
end)

---------------------------------------------------------------------
-- /car
---------------------------------------------------------------------
RegisterNetEvent('arca_core:client:spawnVehicle', function(name)
    local model = joaat(name)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        return Arca.Notify(('"%s" is not a vehicle'):format(name), 'error')
    end
    if not Arca.Functions.LoadModel(model) then
        return Arca.Notify('Vehicle model failed to load', 'error')
    end

    local ped = PlayerPedId()
    local old = GetVehiclePedIsIn(ped, false)
    if old ~= 0 and GetPedInVehicleSeat(old, -1) == ped then
        SetEntityAsMissionEntity(old, true, true)
        DeleteVehicle(old)
    end

    local c = GetEntityCoords(ped)
    local veh = CreateVehicle(model, c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(model)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, 'ARCA' .. Arca.Shared.RandomInt(4))
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetVehicleEngineOn(veh, true, true, false)
    TaskWarpPedIntoVehicle(ped, veh, -1)

    -- let key / fuel scripts know a vehicle was spawned for this player
    TriggerEvent('arca_core:client:vehicleSpawned', veh, GetVehicleNumberPlateText(veh))
    Arca.Notify(('Spawned %s'):format(GetLabelText(GetDisplayNameFromVehicleModel(model))), 'success')
end)

---------------------------------------------------------------------
-- /vector2 /vector3 /vector4
---------------------------------------------------------------------
local function vectorString(kind, c, h)
    if kind == 'vector2' then return ('vector2(%s, %s)'):format(fmt(c.x), fmt(c.y)) end
    if kind == 'vector3' then return ('vector3(%s, %s, %s)'):format(fmt(c.x), fmt(c.y), fmt(c.z)) end
    return ('vector4(%s, %s, %s, %s)'):format(fmt(c.x), fmt(c.y), fmt(c.z), fmt(h))
end

RegisterNetEvent('arca_core:client:copyCoords', function(kind)
    local ped = PlayerPedId()
    copy(vectorString(kind, GetEntityCoords(ped), GetEntityHeading(ped)))
end)

---------------------------------------------------------------------
-- /coords editor: a red ghost ball where you aim, fine-tune it, then copy
---------------------------------------------------------------------
local editing = false

local function rotationToDirection(rot)
    local x, z = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(x))
    return vec3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

local function aimPoint()
    local origin = GetGameplayCamCoord()
    local dest = origin + rotationToDirection(GetGameplayCamRot(2)) * 50.0
    local handle = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, dest.x, dest.y, dest.z, 1 | 16, PlayerPedId(), 4)
    local _, hit, coords = GetShapeTestResult(handle)
    return hit == 1 and coords or nil
end

local controls = {
    copy3 = 38,     -- E
    copy4 = 47,     -- G
    copy2 = 74,     -- H
    lock = 24,      -- left click: lock / unlock the point
    up = 172, down = 173, left = 174, right = 175, -- arrow keys
    fine = 21,      -- shift
    exit = 177,     -- backspace
}

local function stopEditor()
    editing = false
    SendNUIMessage({ action = 'coordsHide' })
end

local function startEditor()
    editing = true
    local locked, point = false, nil
    local zOffset, heading = 0.0, GetEntityHeading(PlayerPedId())
    local lastSent = 0

    CreateThread(function()
        while editing do
            DisableControlAction(0, controls.lock, true)
            DisableControlAction(0, 25, true)
            DisablePlayerFiring(PlayerId(), true)
            for _, key in pairs({ controls.up, controls.down, controls.left, controls.right, controls.exit, controls.copy4, controls.copy2 }) do
                DisableControlAction(0, key, true)
            end

            if not locked then point = aimPoint() or point end

            if point then
                local step = IsControlPressed(0, controls.fine) and 0.01 or 0.05
                if IsDisabledControlPressed(0, controls.up) then zOffset = zOffset + step end
                if IsDisabledControlPressed(0, controls.down) then zOffset = zOffset - step end
                if IsDisabledControlPressed(0, controls.left) then heading = (heading + step * 40) % 360 end
                if IsDisabledControlPressed(0, controls.right) then heading = (heading - step * 40) % 360 end

                local p = point + vec3(0.0, 0.0, zOffset)

                -- ghost ball + heading arrow
                DrawMarker(28, p.x, p.y, p.z, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12, 255, 40, 60, 170, false, false, 2, false, nil, nil, false)
                local h = math.rad(heading)
                local tip = p + vec3(-math.sin(h), math.cos(h), 0.0) * 0.6
                DrawLine(p.x, p.y, p.z, tip.x, tip.y, tip.z, 0, 255, 106, 255)
                DrawMarker(0, p.x, p.y, p.z + 0.35, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.18, 0, 255, 106, 160, true, true, 2, false, nil, nil, false)

                if IsDisabledControlJustPressed(0, controls.lock) then locked = not locked end
                if IsControlJustPressed(0, controls.copy3) then copy(vectorString('vector3', p)) end
                if IsDisabledControlJustPressed(0, controls.copy4) then copy(vectorString('vector4', p, heading)) end
                if IsDisabledControlJustPressed(0, controls.copy2) then copy(vectorString('vector2', p)) end

                local now = GetGameTimer()
                if now - lastSent > 100 then
                    lastSent = now
                    SendNUIMessage({
                        action = 'coords',
                        data = { x = fmt(p.x), y = fmt(p.y), z = fmt(p.z), h = fmt(heading), locked = locked },
                    })
                end
            end

            if IsDisabledControlJustPressed(0, controls.exit) then stopEditor() end
            Wait(0)
        end
    end)
end

RegisterNetEvent('arca_core:client:coordsEditor', function()
    if editing then stopEditor() else startEditor() end
end)
