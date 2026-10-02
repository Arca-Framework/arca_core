RegisterNetEvent('arca_core:client:playerLoaded', function(data)
    Arca.PlayerData = data
    LocalPlayer.state:set('isLoggedIn', true, false)
    TriggerEvent('arca_core:client:onPlayerLoaded', data) -- local hook for other resources
end)

RegisterNetEvent('arca_core:client:playerUnloaded', function()
    Arca.PlayerData = {}
    LocalPlayer.state:set('isLoggedIn', false, false)
    TriggerEvent('arca_core:client:onPlayerUnloaded')
end)

RegisterNetEvent('arca_core:client:setPlayerData', function(data)
    Arca.PlayerData = data
    TriggerEvent('arca_core:client:onPlayerDataUpdated', data)
end)

-- Recover state if arca_core restarts while the player is in-game
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        local data = Arca.Callback.Await('arca_core:getPlayerData')
        if data then
            Arca.PlayerData = data
            LocalPlayer.state:set('isLoggedIn', true, false)
        end
    end)
end)

CreateThread(function()
    while true do
        if Arca.Functions.IsLoggedIn() then
            SetCanAttackFriendly(PlayerPedId(), ArcaConfig.Server.PVP, false)
            NetworkSetFriendlyFireOption(ArcaConfig.Server.PVP)
        end
        Wait(5000)
    end
end)

-- Starvation / dehydration damage
CreateThread(function()
    while true do
        Wait(10000)
        local meta = Arca.PlayerData.metadata
        if meta and Arca.Functions.IsLoggedIn() and ((meta.hunger or 100) <= 0 or (meta.thirst or 100) <= 0) then
            local ped = PlayerPedId()
            if not IsEntityDead(ped) then
                SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - ArcaConfig.Player.StarvationDamage))
            end
        end
    end
end)
