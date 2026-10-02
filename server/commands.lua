Arca.Commands = {}

---@param name string
---@param help string
---@param perm? string permission from ArcaConfig.Server.Permissions, nil = everyone
---@param fn fun(source: number, args: string[], raw: string)
function Arca.Commands.Add(name, help, perm, fn)
    RegisterCommand(name, function(source, args, raw)
        if perm and not Arca.Functions.HasPermission(source, perm) then
            return Arca.Notify(source, 'You do not have permission to do this', 'error')
        end
        fn(source, args, raw)
    end, false)
    TriggerClientEvent('chat:addSuggestion', -1, '/' .. name, help)
end

local function reply(source, msg, nType)
    if source == 0 then return print(msg) end
    Arca.Notify(source, msg, nType)
end

local function targetPlayer(source, id)
    local player = Arca.Functions.GetPlayer(tonumber(id) or -1)
    if not player then reply(source, 'Player not online', 'error') end
    return player
end

Arca.Commands.Add('setjob', 'Set a player job: /setjob id job grade', 'admin', function(source, args)
    local player = targetPlayer(source, args[1])
    if not player then return end
    if player.SetJob(args[2], tonumber(args[3]) or 0) then
        reply(source, 'Job updated', 'success')
    else
        reply(source, 'Invalid job', 'error')
    end
end)

Arca.Commands.Add('setgang', 'Set a player gang: /setgang id gang grade', 'admin', function(source, args)
    local player = targetPlayer(source, args[1])
    if not player then return end
    if player.SetGang(args[2], tonumber(args[3]) or 0) then
        reply(source, 'Gang updated', 'success')
    else
        reply(source, 'Invalid gang', 'error')
    end
end)

Arca.Commands.Add('givemoney', 'Give money: /givemoney id type amount', 'admin', function(source, args)
    local player = targetPlayer(source, args[1])
    if not player then return end
    if player.AddMoney(args[2], tonumber(args[3]), 'admin') then
        reply(source, 'Money given', 'success')
    else
        reply(source, 'Invalid type or amount', 'error')
    end
end)

Arca.Commands.Add('setmoney', 'Set money: /setmoney id type amount', 'admin', function(source, args)
    local player = targetPlayer(source, args[1])
    if not player then return end
    if player.SetMoney(args[2], tonumber(args[3]), 'admin') then
        reply(source, 'Money set', 'success')
    else
        reply(source, 'Invalid type or amount', 'error')
    end
end)

Arca.Commands.Add('job', 'Show your job', nil, function(source)
    local player = Arca.Functions.GetPlayer(source)
    if not player then return end
    local job = player.PlayerData.job
    reply(source, ('%s - %s (%s)'):format(job.label, job.grade.name, job.onduty and 'on duty' or 'off duty'))
end)

Arca.Commands.Add('logout', 'Return to character selection', 'admin', function(source)
    Arca.Player.Logout(source)
end)

exports('AddCommand', Arca.Commands.Add)
