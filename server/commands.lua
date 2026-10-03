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

---------------------------------------------------------------------
-- Admin / dev tools (the work happens client-side in client/commands.lua)
---------------------------------------------------------------------
local function inGame(source)
    if source == 0 then print('This command can only be used in game') return false end
    return true
end

Arca.Commands.Add('fix', 'Repair the vehicle you are in', 'admin', function(source)
    if inGame(source) then TriggerClientEvent('arca_core:client:fixVehicle', source) end
end)

Arca.Commands.Add('tpm', 'Teleport to your map waypoint', 'admin', function(source)
    if inGame(source) then TriggerClientEvent('arca_core:client:tpm', source) end
end)

Arca.Commands.Add('car', 'Spawn a vehicle: /car model', 'admin', function(source, args)
    if not inGame(source) then return end
    local model = args[1]
    if not model or not model:match('^[%w_]+$') then
        return reply(source, 'Usage: /car model', 'error')
    end
    TriggerClientEvent('arca_core:client:spawnVehicle', source, model:lower())
end)

Arca.Commands.Add('tp', 'Teleport: /tp id or /tp x y z', 'admin', function(source, args)
    if not inGame(source) then return end
    -- accepts "x y z" or a pasted "x, y, z"
    local function num(s) return tonumber(((s or ''):gsub(',', ''))) end
    local x, y, z = num(args[1]), num(args[2]), num(args[3])
    if x and y and z then
        return TriggerClientEvent('arca_core:client:teleport', source, vector3(x, y, z))
    end
    local target = tonumber(args[1])
    local ped = target and GetPlayerPed(tostring(target))
    if not ped or ped == 0 then
        return reply(source, 'Usage: /tp id or /tp x y z', 'error')
    end
    TriggerClientEvent('arca_core:client:teleport', source, GetEntityCoords(ped))
end)

for _, kind in ipairs({ 'vector2', 'vector3', 'vector4' }) do
    Arca.Commands.Add(kind, ('Copy your position as a %s'):format(kind), 'admin', function(source)
        if inGame(source) then TriggerClientEvent('arca_core:client:copyCoords', source, kind) end
    end)
end

Arca.Commands.Add('coords', 'Toggle the coords editor', 'admin', function(source)
    if inGame(source) then TriggerClientEvent('arca_core:client:coordsEditor', source) end
end)

exports('AddCommand', Arca.Commands.Add)
