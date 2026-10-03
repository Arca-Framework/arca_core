-- World settings: NPC / traffic density and AI police & dispatch.
-- Edit the values below; the client code at the bottom applies them.

ArcaWorld = {
    -- 0.0 = none, 1.0 = GTA default
    Density = {
        peds = 0.8,             -- people walking around
        scenarioPeds = 0.8,     -- people doing things (sitting, smoking, working...)
        vehicles = 0.6,         -- moving traffic
        parked = 0.6,           -- parked cars
        randomVehicles = 0.6,   -- random cars that spawn out of view
    },

    Police = {
        disableWanted = true,       -- never get wanted stars
        disableRandomCops = true,   -- no AI cops spawning around the city
        disableDispatch = true,     -- no AI police, ambulance, fire, army or helicopter response
        ignorePlayer = true,        -- AI cops that do exist ignore players
    },

    -- other ambient things players usually don't want on an RP server
    DisableIdleCamera = true,       -- stop the camera drifting when AFK
    DisableVehicleRewards = true,   -- no free weapons from police cars / ambulances
    DisableDistantSirens = true,    -- no random sirens in the distance
}

if IsDuplicityVersion() then return end

---------------------------------------------------------------------
-- Client
---------------------------------------------------------------------
local W = ArcaWorld

-- one-off settings
CreateThread(function()
    if W.Police.disableDispatch then
        for service = 1, 15 do EnableDispatchService(service, false) end
    end
    if W.DisableDistantSirens then DistantCopCarSirens(false) end
end)

-- settings that GTA resets, so they run regularly
CreateThread(function()
    while true do
        local player = PlayerId()

        if W.Police.disableWanted then
            SetMaxWantedLevel(0)
            if GetPlayerWantedLevel(player) > 0 then
                ClearPlayerWantedLevel(player)
            end
        end
        if W.Police.disableRandomCops then
            SetCreateRandomCops(false)
            SetCreateRandomCopsNotOnScenarios(false)
            SetCreateRandomCopsOnScenarios(false)
        end
        if W.Police.disableDispatch then
            SetDispatchCopsForPlayer(player, false)
        end
        if W.Police.ignorePlayer then
            SetPoliceIgnorePlayer(player, true)
        end
        if W.DisableIdleCamera then
            InvalidateIdleCam()
            InvalidateVehicleIdleCam()
        end

        Wait(1000)
    end
end)

-- these have to be set every frame
CreateThread(function()
    local d = W.Density
    while true do
        if W.DisableVehicleRewards then DisablePlayerVehicleRewards(PlayerId()) end
        SetPedDensityMultiplierThisFrame(d.peds)
        SetScenarioPedDensityMultiplierThisFrame(d.scenarioPeds, d.scenarioPeds)
        SetVehicleDensityMultiplierThisFrame(d.vehicles)
        SetParkedVehicleDensityMultiplierThisFrame(d.parked)
        SetRandomVehicleDensityMultiplierThisFrame(d.randomVehicles)
        Wait(0)
    end
end)
