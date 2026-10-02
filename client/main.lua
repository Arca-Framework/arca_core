Arca.PlayerData = {}
Arca.Functions = {}

function Arca.Functions.GetPlayerData(cb)
    if cb then return cb(Arca.PlayerData) end
    return Arca.PlayerData
end

function Arca.Functions.IsLoggedIn()
    return LocalPlayer.state.isLoggedIn == true
end

function Arca.Functions.HasJob(name, onDutyOnly)
    local job = Arca.PlayerData.job
    return job and job.name == name and (not onDutyOnly or job.onduty) or false
end

function Arca.Functions.GetClosestPlayer(coords, maxDist)
    coords = coords or GetEntityCoords(PlayerPedId())
    maxDist = maxDist or 5.0
    local closest, closestDist = -1, maxDist
    local me = PlayerId()
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local dist = #(coords - GetEntityCoords(GetPlayerPed(pid)))
            if dist < closestDist then closest, closestDist = pid, dist end
        end
    end
    return closest, closestDist
end

function Arca.Functions.LoadModel(model)
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return model
end

function Arca.Functions.LoadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('GetCoreObject', function() return Arca end)
exports('GetPlayerData', function() return Arca.PlayerData end)
exports('IsLoggedIn', Arca.Functions.IsLoggedIn)
exports('HasJob', Arca.Functions.HasJob)
exports('Notify', function(...) return Arca.Notify(...) end)
