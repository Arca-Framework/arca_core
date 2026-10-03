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
