-- qb-core compatibility (server).
-- arca_core is `provide 'qb-core'`, so exports['qb-core']:GetCoreObject() returns the
-- Arca object. This file adds the qb-named functions, player methods and events on top.
if not ArcaConfig.Bridge.qb then return end

local QBCore = Arca
local Functions = Arca.Functions

local function inventory()
    if GetResourceState('ox_inventory') == 'started' then return 'ox' end
    if GetResourceState('arca_inventory') == 'started' then return 'arca' end
end

---------------------------------------------------------------------
-- Player object additions
---------------------------------------------------------------------
local qbMetadata = {
    ishandcuffed = false,
    tracker = false,
    injail = 0,
    jailitems = {},
    status = {},
    phone = {},
    rep = {},
    callsign = 'NO CALLSIGN',
    bloodtype = 'O+',
    fingerprint = '',
    walletid = '',
    criminalrecord = { hasRecord = false, date = nil },
    licences = { driver = true, business = false, weapon = false },
    inside = { house = nil, apartment = { apartmentType = nil, apartmentId = nil } },
    phonedata = { SerialNumber = '', InstalledApps = {} },
}

Arca.Player.Extensions[#Arca.Player.Extensions + 1] = function(self)
    local src = self.PlayerData.source
    local pd = self.PlayerData

    pd.items = pd.items or {}
    pd.charinfo.account = pd.charinfo.account or ('US0%sARCA%s'):format(math.random(1, 9), Arca.Shared.RandomInt(10))
    pd.metadata.fingerprint = pd.metadata.fingerprint ~= '' and pd.metadata.fingerprint
        or Arca.Shared.RandomStr(2) .. Arca.Shared.RandomInt(3) .. Arca.Shared.RandomStr(1) .. Arca.Shared.RandomInt(2)
    pd.metadata.walletid = pd.metadata.walletid ~= '' and pd.metadata.walletid or 'ARCA-' .. Arca.Shared.RandomInt(8)
    for k, v in pairs(qbMetadata) do
        if pd.metadata[k] == nil then pd.metadata[k] = Arca.Shared.Copy(v) end
    end

    self.Offline = false

    function self.SetPlayerData(key, value)
        if type(key) ~= 'string' or key == 'source' or key == 'citizenid' or key == 'license' then return end
        self.PlayerData[key] = value
        self.UpdatePlayerData()
    end

    function self.AddJobReputation(amount)
        local rep = self.PlayerData.metadata.rep
        local job = self.PlayerData.job.name
        rep[job] = (rep[job] or 0) + (tonumber(amount) or 0)
        self.SetMetaData('rep', rep)
    end

    function self.GetCardSlot() return nil end

    -- Inventory calls go to whichever inventory resource is running
    function self.AddItem(item, amount, slot, info, reason)
        local inv = inventory()
        if inv == 'ox' then return exports.ox_inventory:AddItem(src, item, amount or 1, info, slot) end
        if inv == 'arca' then return exports.arca_inventory:AddItem(src, item, amount or 1, slot, info, reason) end
        return false
    end

    function self.RemoveItem(item, amount, slot, reason)
        local inv = inventory()
        if inv == 'ox' then return exports.ox_inventory:RemoveItem(src, item, amount or 1, nil, slot) end
        if inv == 'arca' then return exports.arca_inventory:RemoveItem(src, item, amount or 1, slot, reason) end
        return false
    end

    function self.GetItemByName(item)
        local inv = inventory()
        if inv == 'ox' then
            local slots = exports.ox_inventory:Search(src, 'slots', item)
            return slots and slots[1]
        end
        if inv == 'arca' then return exports.arca_inventory:GetItemByName(src, item) end
    end

    function self.GetItemsByName(item)
        local inv = inventory()
        if inv == 'ox' then return exports.ox_inventory:Search(src, 'slots', item) or {} end
        if inv == 'arca' then return exports.arca_inventory:GetItemsByName(src, item) or {} end
        return {}
    end

    function self.GetItemBySlot(slot)
        local inv = inventory()
        if inv == 'ox' then return exports.ox_inventory:GetSlot(src, slot) end
        if inv == 'arca' then return exports.arca_inventory:GetItemBySlot(src, slot) end
    end

    function self.ClearInventory()
        local inv = inventory()
        if inv == 'ox' then return exports.ox_inventory:ClearInventory(src) end
        if inv == 'arca' then return exports.arca_inventory:ClearInventory(src) end
    end

    function self.SetInventory(items)
        if inventory() == 'arca' then return exports.arca_inventory:SetInventory(src, items) end
    end
end

---------------------------------------------------------------------
-- QBCore.Functions
---------------------------------------------------------------------
local arcaGetPlayer = Functions.GetPlayer

---@param source number|string server id, or an identifier like 'license:xxx'
function Functions.GetPlayer(source)
    if type(source) == 'string' and not tonumber(source) then
        return arcaGetPlayer(Functions.GetSource(source))
    end
    return arcaGetPlayer(source)
end

function Functions.GetSource(identifier)
    for src, player in pairs(Arca.Players) do
        if player.PlayerData.license == identifier then return src end
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            if id == identifier then return src end
        end
    end
    return 0
end

function Functions.GetQBPlayers() return Arca.Players end

function Functions.GetPlayerByPhone(number)
    for _, player in pairs(Arca.Players) do
        if player.PlayerData.charinfo.phone == number then return player end
    end
end

function Functions.GetPlayersOnDuty(job)
    local list = Functions.GetPlayersByJob(job, true)
    return list, #list
end

function Functions.GetDutyCount(job)
    return #Functions.GetPlayersByJob(job, true)
end

function Functions.GetCoords(entity)
    local c = GetEntityCoords(entity)
    return vector4(c.x, c.y, c.z, GetEntityHeading(entity))
end

function Functions.CreateCallback(name, cb)
    Arca.Callback.Register(name, function(source, ...)
        local p = promise.new()
        cb(source, function(...) p:resolve(table.pack(...)) end, ...)
        local res = Citizen.Await(p)
        return table.unpack(res, 1, res.n)
    end)
end

function Functions.TriggerClientCallback(name, source, cb, ...)
    local args = table.pack(...)
    CreateThread(function()
        cb(Arca.Callback.Await(name, source, nil, table.unpack(args, 1, args.n)))
    end)
end

function Functions.Notify(source, text, nType, length)
    Arca.Notify(source, Arca.QBNotifyArgs(text, nType, length))
end

function Functions.Kick(source, reason)
    DropPlayer(tostring(source), reason or 'Kicked')
end

function Functions.HasItem(source, items, amount)
    local inv = inventory()
    if inv == 'ox' then
        if type(items) == 'table' then
            for _, item in pairs(items) do
                if (exports.ox_inventory:Search(source, 'count', item) or 0) < (amount or 1) then return false end
            end
            return true
        end
        return (exports.ox_inventory:Search(source, 'count', items) or 0) >= (amount or 1)
    end
    if inv == 'arca' then return exports.arca_inventory:HasItem(source, items, amount) end
    return false
end

function Functions.UseItem(source, item)
    local fn = Functions.CanUseItem(item.name)
    if fn then fn(source, item) end
end

function Functions.GetPermission(source)
    local perms = {}
    for _, perm in ipairs(ArcaConfig.Server.Permissions) do
        if IsPlayerAceAllowed(tostring(source), 'arca.' .. perm) then perms[perm] = true end
    end
    return perms
end

function Functions.IsOptin() return true end
function Functions.IsPlayerBanned() return false end
function Functions.IsWhitelisted() return true end
function Functions.AddPermission() print('^3[arca_core] AddPermission is not supported, use aces (arca.<perm>)^7') end
function Functions.RemovePermission() print('^3[arca_core] RemovePermission is not supported, use aces (arca.<perm>)^7') end
function Functions.Debug(...) print(json.encode({ ... }, { indent = true })) end

function Functions.CreateVehicle(source, model, vehType, coords, warp)
    model = type(model) == 'string' and joaat(model) or model
    local ped = GetPlayerPed(source)
    if not coords then
        local c = GetEntityCoords(ped)
        coords = vector4(c.x, c.y, c.z, GetEntityHeading(ped))
    end
    local veh = CreateVehicleServerSetter(model, vehType or 'automobile', coords.x, coords.y, coords.z, coords.w or 0.0)
    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(veh) and GetGameTimer() < timeout do Wait(0) end
    if warp then
        timeout = GetGameTimer() + 5000
        while GetVehiclePedIsIn(ped, false) ~= veh and GetGameTimer() < timeout do
            SetPedIntoVehicle(ped, veh, -1)
            Wait(0)
        end
    end
    return veh
end

function Functions.SpawnVehicle(source, model, coords, warp)
    return Functions.CreateVehicle(source, model, 'automobile', coords, warp)
end

---------------------------------------------------------------------
-- QBCore.Commands.Add(name, help, arguments, argsrequired, callback, permission)
---------------------------------------------------------------------
local arcaAddCommand = Arca.Commands.Add

function Arca.Commands.Add(name, help, a3, a4, a5, a6)
    if type(a5) ~= 'function' then
        return arcaAddCommand(name, help, a3, a4) -- Arca signature
    end
    local arguments, argsRequired, cb, perm = a3 or {}, a4, a5, a6
    if perm == 'user' then perm = nil end
    arcaAddCommand(name, help, perm, function(source, args, raw)
        if argsRequired and #args < #arguments then
            return Arca.Notify(source, 'All arguments must be filled out', 'error')
        end
        cb(source, args, raw)
    end)
end

---------------------------------------------------------------------
-- Shared data management (qb exports)
---------------------------------------------------------------------
local function sharedUpdate(kind, key, value)
    TriggerClientEvent('QBCore:Client:OnSharedUpdate', -1, kind, key, value)
    TriggerEvent('QBCore:Server:UpdateObject')
end

local function addShared(kind, key, value)
    if type(key) ~= 'string' then return false, 'invalid_name' end
    if Arca.Shared[kind][key] then return false, ('%s_exists'):format(kind:lower():sub(1, -2)) end
    Arca.Shared[kind][key] = value
    sharedUpdate(kind, key, value)
    return true, 'success'
end

local function addSharedMany(kind, list)
    local ok, msg = true, 'success'
    for key, value in pairs(list) do
        local res, err = addShared(kind, key, value)
        if not res then ok, msg = false, err end
    end
    return ok, msg
end

local function updateShared(kind, key, value)
    if not Arca.Shared[kind][key] then return false, 'does_not_exist' end
    Arca.Shared[kind][key] = value
    sharedUpdate(kind, key, value)
    return true, 'success'
end

local function removeShared(kind, key)
    if not Arca.Shared[kind][key] then return false, 'does_not_exist' end
    Arca.Shared[kind][key] = nil
    sharedUpdate(kind, key, nil)
    return true, 'success'
end

for _, kind in ipairs({ { 'Job', 'Jobs' }, { 'Gang', 'Gangs' }, { 'Item', 'Items' } }) do
    local single, plural = kind[1], kind[2]
    local add = function(key, value) return addShared(plural, key, value) end
    local addMany = function(list) return addSharedMany(plural, list) end
    local update = function(key, value) return updateShared(plural, key, value) end
    local remove = function(key) return removeShared(plural, key) end

    Functions['Add' .. single] = add
    Functions['Add' .. plural] = addMany
    Functions['Update' .. single] = update
    Functions['Remove' .. single] = remove
    exports('Add' .. single, add)
    exports('Add' .. plural, addMany)
    exports('Update' .. single, update)
    exports('Remove' .. single, remove)
end

---------------------------------------------------------------------
-- Events: Arca -> QBCore
---------------------------------------------------------------------
AddEventHandler('arca_core:server:playerLoaded', function(player)
    TriggerEvent('QBCore:Server:PlayerLoaded', player)
end)

AddEventHandler('arca_core:server:playerUnloaded', function(src)
    TriggerEvent('QBCore:Server:OnPlayerUnload', src)
end)

AddEventHandler('arca_core:server:onJobUpdate', function(src, job)
    TriggerEvent('QBCore:Server:OnJobUpdate', src, job)
end)

AddEventHandler('arca_core:server:onGangUpdate', function(src, gang)
    TriggerEvent('QBCore:Server:OnGangUpdate', src, gang)
end)

AddEventHandler('arca_core:server:onMoneyChange', function(src, mType, delta, reason, op)
    TriggerEvent('QBCore:Server:OnMoneyChange', src, mType, math.abs(delta), op, reason)
end)

AddEventHandler('arca_core:server:setDuty', function(src, duty)
    TriggerEvent('QBCore:Server:SetDuty', src, duty)
end)

---------------------------------------------------------------------
-- Events: QBCore net events qb resources send to the server
---------------------------------------------------------------------
RegisterNetEvent('QBCore:ToggleDuty', function()
    local player = Functions.GetPlayer(source)
    if not player then return end
    player.SetJobDuty(not player.PlayerData.job.onduty)
    Arca.Notify(source, player.PlayerData.job.onduty and 'You are now on duty' or 'You are now off duty')
end)

-- qb clients may only set these through the network
local clientMetadata = { hunger = true, thirst = true }

RegisterNetEvent('QBCore:Server:SetMetaData', function(key, value)
    local player = Functions.GetPlayer(source)
    if not player or not clientMetadata[key] then return end
    value = tonumber(value)
    if not value then return end
    player.SetMetaData(key, math.max(0, math.min(100, value)))
end)

RegisterNetEvent('QBCore:Server:UseItem', function(item)
    if type(item) ~= 'table' or type(item.name) ~= 'string' then return end
    if not Functions.HasItem(source, item.name) then return end
    Functions.UseItem(source, item)
end)
