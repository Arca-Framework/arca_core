AddEventHandler('playerDropped', function(reason)
    local src = source
    local player = Arca.Players[src]
    if not player then return end
    Arca.Debug(player.PlayerData.citizenid, 'dropped:', reason)
    Arca.Player.Logout(src)
end)

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    if not Arca.Functions.GetIdentifier(src) then
        deferrals.done('Arca: no Rockstar license found. Restart FiveM and try again.')
        return
    end
    deferrals.done()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Arca.Player.SaveAll()
end)

CreateThread(function()
    local interval = ArcaConfig.Player.SaveInterval * 60000
    while true do
        Wait(interval)
        Arca.Player.SaveAll()
    end
end)

-- Hunger / thirst decay
CreateThread(function()
    local decay = ArcaConfig.Player.StatusDecay
    while true do
        Wait(60000)
        for _, player in pairs(Arca.Players) do
            local meta = player.PlayerData.metadata
            if not meta.isdead then
                meta.hunger = math.max(0, (meta.hunger or 100) - decay.hunger)
                meta.thirst = math.max(0, (meta.thirst or 100) - decay.thirst)
                player.UpdatePlayerData()
            end
        end
    end
end)

-- Paychecks every SaveInterval would be odd; keep a separate 15 minute cycle
CreateThread(function()
    while true do
        Wait(15 * 60000)
        for _, player in pairs(Arca.Players) do
            local job = player.PlayerData.job
            if job.payment > 0 and job.onduty then
                player.AddMoney('bank', job.payment, 'paycheck')
                Arca.Notify(player.PlayerData.source, ('You received your paycheck of $%d'):format(job.payment), 'success')
            end
        end
    end
end)

RegisterNetEvent('arca_core:server:toggleDuty', function()
    local player = Arca.Functions.GetPlayer(source)
    if not player then return end
    player.SetJobDuty(not player.PlayerData.job.onduty)
end)

-- Client asks for a fresh copy (e.g. after a resource restart)
Arca.Callback.Register('arca_core:getPlayerData', function(source)
    local player = Arca.Functions.GetPlayer(source)
    return player and player.PlayerData
end)
