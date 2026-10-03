-- Job menu: switch between the jobs you hold and go on / off duty (/jobs, radial menu)

local function openJobs()
    local data = Arca.Callback.Await('arca_core:getJobs')
    if not data then return end

    local active
    for _, job in ipairs(data.jobs) do if job.active then active = job end end

    local options = {}
    if active then
        options[#options + 1] = {
            title = data.onduty and 'Go off duty' or 'Go on duty',
            description = ('%s · %s'):format(active.label, active.gradeName),
            icon = data.onduty and 'fa-solid fa-toggle-on' or 'fa-solid fa-toggle-off',
            onSelect = function() TriggerServerEvent('arca_core:server:requestDuty', not data.onduty) end,
        }
    end

    for _, job in ipairs(data.jobs) do
        options[#options + 1] = {
            title = job.label .. (job.active and '  ·  active' or ''),
            description = ('%s%s · $%d paycheck'):format(job.gradeName, job.isboss and ' (boss)' or '', job.payment),
            icon = job.active and 'fa-solid fa-briefcase' or 'fa-regular fa-briefcase',
            disabled = job.active,
            onSelect = function() TriggerServerEvent('arca_core:server:switchJob', job.name) end,
        }
    end

    if data.active ~= 'unemployed' then
        options[#options + 1] = {
            title = 'Clock out (civilian)',
            description = 'Switch to no job without quitting',
            icon = 'fa-solid fa-user',
            onSelect = function() TriggerServerEvent('arca_core:server:switchJob', 'unemployed') end,
        }
    end

    if #data.jobs == 0 then
        options[#options + 1] = { title = 'No jobs yet', description = 'Get hired to see your jobs here', icon = 'fa-solid fa-circle-info', disabled = true }
    end

    Arca.RegisterContext({ id = 'arca_core:jobs', title = ('My jobs (%d/%d)'):format(#data.jobs, data.max), options = options })
    Arca.ShowContext('arca_core:jobs')
end

RegisterNetEvent('arca_core:client:openJobs', openJobs)
exports('OpenJobMenu', openJobs)

exports('GetJobs', function()
    local meta = Arca.PlayerData.metadata or {}
    return type(meta.jobs) == 'table' and meta.jobs or {}
end)
exports('IsOnDuty', function(job)
    local j = Arca.PlayerData.job
    return j ~= nil and j.onduty == true and (not job or j.name == job)
end)

-- radial menu entry
CreateThread(function()
    Arca.AddRadialItem({ id = 'arca_jobs', label = 'Jobs', icon = 'fa-solid fa-briefcase', onSelect = openJobs })
end)

---------------------------------------------------------------------
-- Vehicle controls in the radial menu
---------------------------------------------------------------------
local function myVehicle()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then Arca.Notify('You\'re not in a vehicle', 'error') return nil end
    return veh
end

local function toggleDoor(door)
    local veh = myVehicle()
    if not veh then return end
    if GetVehicleDoorAngleRatio(veh, door) > 0.1 then SetVehicleDoorShut(veh, door, false) else SetVehicleDoorOpen(veh, door, false, false) end
end

local windowsDown = false

CreateThread(function()
    Arca.RegisterRadial({ id = 'arca_vehicle', items = {
        { id = 'veh_engine', label = 'Engine', icon = 'fa-solid fa-power-off', keepOpen = true, onSelect = function()
            local veh = myVehicle()
            if veh then SetVehicleEngineOn(veh, not GetIsVehicleEngineRunning(veh), false, true) end
        end },
        { id = 'veh_hood', label = 'Hood', icon = 'fa-solid fa-car-side', keepOpen = true, onSelect = function() toggleDoor(4) end },
        { id = 'veh_trunk', label = 'Trunk', icon = 'fa-solid fa-car-rear', keepOpen = true, onSelect = function() toggleDoor(5) end },
        { id = 'veh_windows', label = 'Windows', icon = 'fa-solid fa-wind', keepOpen = true, onSelect = function()
            local veh = myVehicle()
            if not veh then return end
            windowsDown = not windowsDown
            if windowsDown then RollDownWindows(veh) else for i = 0, 3 do RollUpWindow(veh, i) end end
        end },
        { id = 'veh_door_fl', label = 'Driver door', icon = 'fa-solid fa-door-open', keepOpen = true, onSelect = function() toggleDoor(0) end },
        { id = 'veh_door_fr', label = 'Passenger door', icon = 'fa-solid fa-door-open', keepOpen = true, onSelect = function() toggleDoor(1) end },
    } })
    Arca.AddRadialItem({ id = 'arca_vehicle', label = 'Vehicle', icon = 'fa-solid fa-car', menu = 'arca_vehicle' })
end)
