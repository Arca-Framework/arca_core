-- qb-core compatibility (client). See bridge/qb/server.lua.
if not ArcaConfig.Bridge.qb then return end

local Functions = Arca.Functions

local function inventory()
    if GetResourceState('ox_inventory') == 'started' then return 'ox' end
    if GetResourceState('arca_inventory') == 'started' then return 'arca' end
end

---------------------------------------------------------------------
-- QBCore.Functions
---------------------------------------------------------------------
function Functions.TriggerCallback(name, cb, ...)
    Arca.Callback.Trigger(name, cb, ...)
end

function Functions.CreateClientCallback(name, cb)
    Arca.Callback.Register(name, function(...)
        local p = promise.new()
        cb(function(...) p:resolve(table.pack(...)) end, ...)
        local res = Citizen.Await(p)
        return table.unpack(res, 1, res.n)
    end)
end

function Functions.Notify(text, nType, length)
    Arca.Notify(Arca.QBNotifyArgs(text, nType, length))
end

function Functions.HasItem(items, amount)
    local inv = inventory()
    amount = amount or 1
    if inv == 'ox' then
        if type(items) == 'table' then
            for _, item in pairs(items) do
                if exports.ox_inventory:Search('count', item) < amount then return false end
            end
            return true
        end
        return exports.ox_inventory:Search('count', items) >= amount
    end
    if inv == 'arca' then return exports.arca_inventory:HasItem(items, amount) end
    return false
end

Functions.RequestAnimDict = Functions.LoadAnimDict

function Functions.GetPlayers() return GetActivePlayers() end

function Functions.GetPlayersFromCoords(coords, distance)
    coords = coords or GetEntityCoords(PlayerPedId())
    distance = distance or 5.0
    local list = {}
    for _, pid in ipairs(GetActivePlayers()) do
        if #(coords - GetEntityCoords(GetPlayerPed(pid))) <= distance then list[#list + 1] = pid end
    end
    return list
end

function Functions.GetPeds(ignoreList)
    local ignore = {}
    for _, p in ipairs(ignoreList or {}) do ignore[p] = true end
    local list = {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        if not ignore[ped] then list[#list + 1] = ped end
    end
    return list
end

function Functions.GetVehicles() return GetGamePool('CVehicle') end
function Functions.GetObjects() return GetGamePool('CObject') end

local function closest(pool, coords, filter)
    coords = coords and (type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords) or GetEntityCoords(PlayerPedId())
    local best, bestDist = -1, -1
    for _, ent in ipairs(pool) do
        if not filter or filter(ent) then
            local dist = #(coords - GetEntityCoords(ent))
            if bestDist == -1 or dist < bestDist then best, bestDist = ent, dist end
        end
    end
    return best, bestDist
end

function Functions.GetClosestPed(coords, ignoreList)
    local me = PlayerPedId()
    return closest(Functions.GetPeds(ignoreList), coords, function(p) return p ~= me end)
end

function Functions.GetClosestVehicle(coords) return closest(GetGamePool('CVehicle'), coords) end
function Functions.GetClosestObject(coords) return closest(GetGamePool('CObject'), coords) end

function Functions.DrawText(x, y, width, height, scale, r, g, b, a, text)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropShadow()
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x - width / 2, y - height / 2 + 0.005)
end

function Functions.DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

function Functions.Progressbar(_, label, duration, useWhileDead, canCancel, disableControls, animation, prop, _, onFinish, onCancel)
    CreateThread(function()
        local anim
        if animation then
            anim = animation.task and { scenario = animation.task }
                or { dict = animation.animDict, clip = animation.anim, flag = animation.flags }
        end
        local propData
        if prop and prop.model then
            propData = { model = prop.model, bone = prop.bone, pos = prop.coords, rot = prop.rotation }
        end
        local dc = disableControls or {}
        local ok = Arca.Progress({
            label = label,
            duration = duration,
            useWhileDead = useWhileDead,
            canCancel = canCancel,
            disable = { move = dc.disableMovement, car = dc.disableCarMovement, combat = dc.disableCombat, mouse = dc.disableMouse },
            anim = anim,
            prop = propData,
        })
        if ok then
            if onFinish then onFinish() end
        elseif onCancel then
            onCancel()
        end
    end)
end

function Functions.GetPlate(vehicle)
    if vehicle == 0 then return end
    return Arca.Shared.Trim(GetVehicleNumberPlateText(vehicle))
end

function Functions.GetStreetNametAtCoords(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return { main = GetStreetNameFromHashKey(s1), cross = GetStreetNameFromHashKey(s2) }
end

function Functions.GetZoneAtCoords(coords)
    return GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
end

function Functions.GetCardinalDirection(entity)
    local h = GetEntityHeading(entity or PlayerPedId())
    if h >= 315 or h < 45 then return 'North' end
    if h < 135 then return 'West' end
    if h < 225 then return 'South' end
    return 'East'
end

function Functions.GetCurrentTime()
    local hour, minute = GetClockHours(), GetClockMinutes()
    return { hour = hour, min = minute, ampm = hour >= 12 and 'PM' or 'AM' }
end

function Functions.SpawnVehicle(model, cb, coords, isNetworked, teleportInto)
    local ped = PlayerPedId()
    model = Functions.LoadModel(model)
    if not model then return end
    if not coords then
        local c = GetEntityCoords(ped)
        coords = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
    elseif type(coords) == 'table' then
        coords = vector4(coords.x, coords.y, coords.z, coords.w or GetEntityHeading(ped))
    end
    isNetworked = isNetworked == nil and true or isNetworked
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, isNetworked, false)
    if isNetworked then
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(veh), true)
    end
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetModelAsNoLongerNeeded(model)
    if teleportInto then TaskWarpPedIntoVehicle(ped, veh, -1) end
    if cb then cb(veh) end
    return veh
end

function Functions.DeleteVehicle(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

---------------------------------------------------------------------
-- Vehicle properties (qb format)
---------------------------------------------------------------------
local modNames = {
    [0] = 'modSpoilers', 'modFrontBumper', 'modRearBumper', 'modSideSkirt', 'modExhaust', 'modFrame',
    'modGrille', 'modHood', 'modFender', 'modRightFender', 'modRoof', 'modEngine', 'modBrakes',
    'modTransmission', 'modHorns', 'modSuspension', 'modArmor', nil, nil, nil, nil, nil, nil,
    'modFrontWheels', 'modBackWheels', 'modPlateHolder', 'modVanityPlate', 'modTrimA', 'modOrnaments',
    'modDashboard', 'modDial', 'modDoorSpeaker', 'modSeats', 'modSteeringWheel', 'modShifterLeavers',
    'modAPlate', 'modSpeakers', 'modTrunk', 'modHydrolic', 'modEngineBlock', 'modAirFilter', 'modStruts',
    'modArchCover', 'modAerials', 'modTrimB', 'modTank', 'modWindows', nil, 'modLivery',
}
local toggleMods = { [18] = 'modTurbo', [20] = 'modSmokeEnabled', [22] = 'modXenon' }

function Functions.GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local color1, color2 = GetVehicleColours(vehicle)
    local pearl, wheelColor = GetVehicleExtraColours(vehicle)
    if GetIsVehiclePrimaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
        color1 = { r, g, b }
    end
    if GetIsVehicleSecondaryColourCustom(vehicle) then
        local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
        color2 = { r, g, b }
    end

    local extras = {}
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i) end
    end

    local props = {
        model = GetEntityModel(vehicle),
        plate = Functions.GetPlate(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = Arca.Shared.Round(GetVehicleBodyHealth(vehicle), 1),
        engineHealth = Arca.Shared.Round(GetVehicleEngineHealth(vehicle), 1),
        tankHealth = Arca.Shared.Round(GetVehiclePetrolTankHealth(vehicle), 1),
        fuelLevel = Arca.Shared.Round(GetVehicleFuelLevel(vehicle), 1),
        dirtLevel = Arca.Shared.Round(GetVehicleDirtLevel(vehicle), 1),
        oilLevel = Arca.Shared.Round(GetVehicleOilLevel(vehicle), 1),
        color1 = color1,
        color2 = color2,
        pearlescentColor = pearl,
        wheelColor = wheelColor,
        dashboardColor = GetVehicleDashboardColour(vehicle),
        interiorColor = GetVehicleInteriorColour(vehicle),
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        neonEnabled = {
            IsVehicleNeonLightEnabled(vehicle, 0), IsVehicleNeonLightEnabled(vehicle, 1),
            IsVehicleNeonLightEnabled(vehicle, 2), IsVehicleNeonLightEnabled(vehicle, 3),
        },
        neonColor = table.pack(GetVehicleNeonLightsColour(vehicle)),
        tyreSmokeColor = table.pack(GetVehicleTyreSmokeColor(vehicle)),
        extras = extras,
        liveries = GetVehicleLivery(vehicle),
    }
    props.neonColor.n, props.tyreSmokeColor.n = nil, nil

    for id, name in pairs(modNames) do props[name] = GetVehicleMod(vehicle, id) end
    for id, name in pairs(toggleMods) do props[name] = IsToggleModOn(vehicle, id) end
    return props
end

function Functions.SetVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) or type(props) ~= 'table' then return end
    SetVehicleModKit(vehicle, 0)

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end
    if props.oilLevel then SetVehicleOilLevel(vehicle, props.oilLevel + 0.0) end

    local c1, c2 = GetVehicleColours(vehicle)
    if type(props.color1) == 'table' then
        SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3])
    elseif props.color1 then
        ClearVehicleCustomPrimaryColour(vehicle)
        c1 = props.color1
    end
    if type(props.color2) == 'table' then
        SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3])
    elseif props.color2 then
        ClearVehicleCustomSecondaryColour(vehicle)
        c2 = props.color2
    end
    SetVehicleColours(vehicle, c1, c2)

    local pearl, wheel = GetVehicleExtraColours(vehicle)
    SetVehicleExtraColours(vehicle, props.pearlescentColor or pearl, props.wheelColor or wheel)
    if props.dashboardColor then SetVehicleDashboardColour(vehicle, props.dashboardColor) end
    if props.interiorColor then SetVehicleInteriorColour(vehicle, props.interiorColor) end
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end
    if props.xenonColor then SetVehicleXenonLightsColor(vehicle, props.xenonColor) end

    if props.neonEnabled then
        for i = 1, 4 do SetVehicleNeonLightEnabled(vehicle, i - 1, props.neonEnabled[i] and true or false) end
    end
    if props.neonColor then SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3]) end
    if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3]) end

    if props.extras then
        for id, enabled in pairs(props.extras) do
            SetVehicleExtra(vehicle, tonumber(id), not enabled)
        end
    end

    for id, name in pairs(modNames) do
        if props[name] then SetVehicleMod(vehicle, id, props[name], false) end
    end
    for id, name in pairs(toggleMods) do
        if props[name] ~= nil then ToggleVehicleMod(vehicle, id, props[name]) end
    end
    if props.liveries then SetVehicleLivery(vehicle, props.liveries) end
end

---------------------------------------------------------------------
-- qb-core client exports (DrawText) -> Arca TextUI
---------------------------------------------------------------------
local positions = { left = 'left-center', right = 'right-center', top = 'top-center', bottom = 'bottom-center' }

local function drawText(text, position)
    Arca.ShowTextUI(text, { position = positions[position] or 'left-center' })
end

exports('DrawText', drawText)
exports('ChangeText', drawText)
exports('HideText', Arca.HideTextUI)
exports('KeyPressed', Arca.HideTextUI)

---------------------------------------------------------------------
-- Events: Arca -> QBCore
---------------------------------------------------------------------
AddEventHandler('arca_core:client:onPlayerLoaded', function()
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
end)

AddEventHandler('arca_core:client:onPlayerUnloaded', function()
    TriggerEvent('QBCore:Client:OnPlayerUnload')
end)

AddEventHandler('arca_core:client:onPlayerDataUpdated', function(data)
    TriggerEvent('QBCore:Player:SetPlayerData', data)
end)

RegisterNetEvent('arca_core:client:onJobUpdate', function(job)
    TriggerEvent('QBCore:Client:OnJobUpdate', job)
end)

RegisterNetEvent('arca_core:client:onGangUpdate', function(gang)
    TriggerEvent('QBCore:Client:OnGangUpdate', gang)
end)

RegisterNetEvent('arca_core:client:onMoneyChange', function(mType, delta, reason, op)
    TriggerEvent('QBCore:Client:OnMoneyChange', mType, math.abs(delta), op, reason)
end)

RegisterNetEvent('arca_core:client:setDuty', function(duty)
    TriggerEvent('QBCore:Client:SetDuty', duty)
end)

---------------------------------------------------------------------
-- Events qb resources send to the client
---------------------------------------------------------------------
RegisterNetEvent('QBCore:Notify', function(text, nType, length)
    Functions.Notify(text, nType, length)
end)

RegisterNetEvent('QBCore:Client:OnSharedUpdate', function(kind, key, value)
    if Arca.Shared[kind] then Arca.Shared[kind][key] = value end
end)
