Arca.Players = {}       -- [source] = player object
Arca.Functions = {}

---@param source number
---@param idType? string defaults to 'license'
function Arca.Functions.GetIdentifier(source, idType)
    idType = idType or 'license'
    return GetPlayerIdentifierByType(tostring(source), idType)
end

---@param source number
function Arca.Functions.GetPlayer(source)
    return Arca.Players[tonumber(source)]
end

---@param citizenid string
function Arca.Functions.GetPlayerByCitizenId(citizenid)
    for _, player in pairs(Arca.Players) do
        if player.PlayerData.citizenid == citizenid then return player end
    end
end

---@return number[] sources of all logged-in players
function Arca.Functions.GetPlayers()
    local list = {}
    for src in pairs(Arca.Players) do list[#list + 1] = src end
    return list
end

---@param jobName string
---@param onDutyOnly? boolean
function Arca.Functions.GetPlayersByJob(jobName, onDutyOnly)
    local list = {}
    for src, player in pairs(Arca.Players) do
        local job = player.PlayerData.job
        if job.name == jobName and (not onDutyOnly or job.onduty) then
            list[#list + 1] = src
        end
    end
    return list
end

---Checks ace "arca.<perm>". Higher permissions in config inherit lower ones.
---@param source number
---@param perm string
function Arca.Functions.HasPermission(source, perm)
    if source == 0 then return true end
    local src = tostring(source)
    local perms = ArcaConfig.Server.Permissions
    for i = 1, #perms do
        if IsPlayerAceAllowed(src, 'arca.' .. perms[i]) then return true end
        if perms[i] == perm then break end
    end
    return false
end

---Register a usable item handler (consumed by arca_inventory)
local usableItems = {}   -- [item] = handler
local usableOwner = {}   -- [item] = resource that registered it
function Arca.Functions.CreateUseableItem(item, fn)
    usableItems[item] = fn
    usableOwner[item] = GetInvokingResource() or GetCurrentResourceName()
end
function Arca.Functions.CanUseItem(item) return usableItems[item] end

-- a stopped resource's handlers can't be called any more: forget them
-- (they're registered again when the resource starts)
AddEventHandler('onResourceStop', function(resource)
    for item, owner in pairs(usableOwner) do
        if owner == resource then usableItems[item], usableOwner[item] = nil, nil end
    end
end)

function Arca.Functions.AddJob(name, data) Arca.Shared.Jobs[name] = data end
function Arca.Functions.AddGang(name, data) Arca.Shared.Gangs[name] = data end

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
exports('GetCoreObject', function() return Arca end)
exports('GetPlayer', Arca.Functions.GetPlayer)
exports('GetPlayerByCitizenId', Arca.Functions.GetPlayerByCitizenId)
exports('GetPlayers', Arca.Functions.GetPlayers)
exports('GetPlayersByJob', Arca.Functions.GetPlayersByJob)
exports('HasPermission', Arca.Functions.HasPermission)
exports('Notify', function(...) return Arca.Notify(...) end)
exports('RegisterCallback', function(...) return Arca.Callback.Register(...) end)
exports('CreateUseableItem', Arca.Functions.CreateUseableItem)
exports('CanUseItem', Arca.Functions.CanUseItem)
exports('GetJobs', function() return Arca.Shared.Jobs end)
exports('GetGangs', function() return Arca.Shared.Gangs end)
