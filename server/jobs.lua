-- Multi-job: a character can hold several jobs, switch the active one, and go on / off duty.
--
--   PlayerData.job               the ACTIVE job (same shape as before, so every script keeps working)
--   PlayerData.metadata.jobs     every job they hold: { police = 2, mechanic = 0 }
--
-- Paychecks, job checks, arca_target groups etc. all use the active job + its duty state.

local cfg = ArcaConfig.Jobs

local function held(player)
    local meta = player.PlayerData.metadata
    if type(meta.jobs) ~= 'table' then meta.jobs = {} end
    return meta.jobs
end

local function save(player)
    player.SetMetaData('jobs', held(player))
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local function jobDef(name) return Arca.Shared.Jobs[name] end

---------------------------------------------------------------------
-- Player methods (added to every player object)
---------------------------------------------------------------------
Arca.Player.Extensions[#Arca.Player.Extensions + 1] = function(player)
    local setActive = player.SetJob -- the original: sets the active job only

    ---Hold a job without switching to it. Returns false if it doesn't exist or they hold too many.
    function player.AddJob(name, grade)
        if not jobDef(name) or name == 'unemployed' then return false, 'Unknown job' end
        local jobs = held(player)
        if jobs[name] == nil and count(jobs) >= cfg.MaxJobs then return false, ('Can only hold %d jobs'):format(cfg.MaxJobs) end
        jobs[name] = tonumber(grade) or 0
        save(player)
        -- holding a new grade of the active job updates it in place
        if player.PlayerData.job.name == name then setActive(name, jobs[name]) end
        TriggerEvent('arca_core:server:jobsChanged', player.PlayerData.source, jobs)
        return true
    end

    ---Stop holding a job. If it was active they switch to their next job (or unemployed).
    function player.RemoveJob(name)
        local jobs = held(player)
        if jobs[name] == nil then return false end
        jobs[name] = nil
        save(player)
        if player.PlayerData.job.name == name then
            local nextJob, nextGrade = next(jobs)
            setActive(nextJob or 'unemployed', nextGrade or 0)
            player.SetJobDuty(false)
        end
        TriggerEvent('arca_core:server:jobsChanged', player.PlayerData.source, jobs)
        return true
    end

    ---Make one of their jobs the active one (they go off duty unless the job is defaultDuty).
    function player.SwitchJob(name)
        local jobs = held(player)
        if name ~= 'unemployed' and jobs[name] == nil then return false, 'You don\'t have that job' end
        if player.PlayerData.job.name == name then return true end
        setActive(name, jobs[name] or 0)
        local def = jobDef(name)
        player.SetJobDuty(cfg.DutyOnSwitch or (def and def.defaultDuty and cfg.RespectDefaultDuty) or false)
        return true
    end

    ---SetJob keeps qb behaviour (become this job now) and also adds it to the held jobs.
    function player.SetJob(name, grade)
        if name ~= 'unemployed' then
            local ok = player.AddJob(name, grade)
            if not ok and held(player)[name] == nil then
                -- full: replace the active job's slot
                held(player)[player.PlayerData.job.name] = nil
                held(player)[name] = tonumber(grade) or 0
                save(player)
            end
        end
        return setActive(name, grade)
    end

    ---Every job they hold, with labels, for menus
    function player.GetJobs()
        local list = {}
        for name, grade in pairs(held(player)) do
            local def = jobDef(name)
            if def then
                local g = def.grades[tostring(grade)] or def.grades[grade] or {}
                list[#list + 1] = {
                    name = name, label = def.label, grade = grade, gradeName = g.name or tostring(grade),
                    payment = g.payment or 0, isboss = g.isboss or false,
                    active = player.PlayerData.job.name == name,
                }
            end
        end
        table.sort(list, function(a, b) return a.label < b.label end)
        return list
    end

    ---Do they hold this job (at least this grade)? Not just the active one.
    function player.HoldsJob(name, minGrade)
        local g = held(player)[name]
        return g ~= nil and g >= (minGrade or 0)
    end

    -- the active job always counts as held (characters made before multi-job)
    local active = player.PlayerData.job
    if active.name ~= 'unemployed' and held(player)[active.name] == nil then
        held(player)[active.name] = active.grade.level
    end
    -- drop jobs that were removed from jobs.lua
    for name in pairs(held(player)) do
        if not jobDef(name) then held(player)[name] = nil end
    end
end

---------------------------------------------------------------------
-- Duty helpers
---------------------------------------------------------------------
local function getPlayer(src) return Arca.Functions.GetPlayer(src) end

local function setDuty(src, state)
    local player = getPlayer(src)
    if not player then return false end
    if player.PlayerData.job.name == 'unemployed' then return false end
    player.SetJobDuty(state and true or false)
    Arca.Notify(src, state and ('On duty · %s'):format(player.PlayerData.job.label) or 'Off duty', state and 'success' or 'inform')
    return true
end

local function onDuty(job)
    local list = {}
    for src, player in pairs(Arca.Players) do
        local j = player.PlayerData.job
        if j.onduty and (not job or j.name == job) then list[#list + 1] = src end
    end
    return list
end

---------------------------------------------------------------------
-- Client requests (job menu)
---------------------------------------------------------------------
Arca.Callback.Register('arca_core:getJobs', function(src)
    local player = getPlayer(src)
    if not player then return nil end
    return { jobs = player.GetJobs(), active = player.PlayerData.job.name, onduty = player.PlayerData.job.onduty, max = cfg.MaxJobs }
end)

RegisterNetEvent('arca_core:server:switchJob', function(name)
    local src = source
    local player = getPlayer(src)
    if not player then return end
    local ok, err = player.SwitchJob(tostring(name))
    if not ok then return Arca.Notify(src, err or 'Can\'t switch', 'error') end
    Arca.Notify(src, ('Now working as %s'):format(player.PlayerData.job.label), 'success')
end)

RegisterNetEvent('arca_core:server:requestDuty', function(state)
    setDuty(source, state)
end)

RegisterNetEvent('arca_core:server:quitJob', function(name)
    local player = getPlayer(source)
    if player and player.RemoveJob(tostring(name)) then Arca.Notify(source, 'You quit that job', 'inform') end
end)

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------
Arca.Commands.Add('jobs', 'Your jobs: switch and go on / off duty', nil, function(source)
    if source ~= 0 then TriggerClientEvent('arca_core:client:openJobs', source) end
end)

Arca.Commands.Add('duty', 'Go on / off duty', nil, function(source)
    local player = getPlayer(source)
    if player then setDuty(source, not player.PlayerData.job.onduty) end
end)

local function reply(src, msg, kind) if src == 0 then print(msg) else Arca.Notify(src, msg, kind) end end

Arca.Commands.Add('addjob', 'Give a player a job: /addjob id job grade', 'admin', function(source, args)
    local player = getPlayer(tonumber(args[1]) or -1)
    if not player then return reply(source, 'Player not online', 'error') end
    local ok, err = player.AddJob(args[2], tonumber(args[3]) or 0)
    reply(source, ok and 'Job added' or (err or 'Invalid job'), ok and 'success' or 'error')
end)

Arca.Commands.Add('removejob', 'Remove a job from a player: /removejob id job', 'admin', function(source, args)
    local player = getPlayer(tonumber(args[1]) or -1)
    if not player then return reply(source, 'Player not online', 'error') end
    reply(source, player.RemoveJob(args[2]) and 'Job removed' or 'They don\'t have that job', 'inform')
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
local function withPlayer(fn)
    return function(src, ...)
        local player = getPlayer(src)
        if not player then return false end
        return fn(player, ...)
    end
end

exports('AddPlayerJob', withPlayer(function(p, name, grade) return p.AddJob(name, grade) end))
exports('RemovePlayerJob', withPlayer(function(p, name) return p.RemoveJob(name) end))
exports('SwitchJob', withPlayer(function(p, name) return p.SwitchJob(name) end))
exports('GetPlayerJobs', withPlayer(function(p) return p.GetJobs() end))
exports('HoldsJob', withPlayer(function(p, name, minGrade) return p.HoldsJob(name, minGrade) end))
exports('SetDuty', setDuty)
exports('ToggleDuty', function(src) local p = getPlayer(src) return p and setDuty(src, not p.PlayerData.job.onduty) end)
exports('IsOnDuty', function(src, job)
    local p = getPlayer(src)
    if not p then return false end
    local j = p.PlayerData.job
    return j.onduty and (not job or j.name == job)
end)
exports('GetOnDuty', onDuty)                                   -- sources on duty (optionally for one job)
exports('GetDutyCount', function(job) return #onDuty(job) end)
