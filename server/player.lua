Arca.Player = {}
Arca.Player.Extensions = {} ---@type fun(player: table)[]

local json = json

local function decode(value, fallback)
    if type(value) == 'string' then
        local ok, res = pcall(json.decode, value)
        if ok and res then return res end
    end
    return fallback
end

local function generateCitizenId()
    while true do
        local id = Arca.Shared.RandomStr(3) .. Arca.Shared.RandomInt(5)
        if not MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ?', { id }) then
            return id
        end
    end
end

local function buildJob(name, grade, onduty)
    local job = Arca.Shared.Jobs[name] or Arca.Shared.Jobs.unemployed
    name = Arca.Shared.Jobs[name] and name or 'unemployed'
    grade = tonumber(grade) or 0
    local g = job.grades[tostring(grade)] or job.grades[grade] or job.grades['0'] or job.grades[0]
    if onduty == nil then onduty = job.defaultDuty end
    return {
        name = name,
        label = job.label,
        type = job.type,
        onduty = onduty,
        payment = g.payment or 0,
        isboss = g.isboss or false,
        grade = { level = grade, name = g.name },
    }
end

local function buildGang(name, grade)
    local gang = Arca.Shared.Gangs[name] or Arca.Shared.Gangs.none
    name = Arca.Shared.Gangs[name] and name or 'none'
    grade = tonumber(grade) or 0
    local g = gang.grades[tostring(grade)] or gang.grades[grade] or gang.grades['0'] or gang.grades[0]
    return {
        name = name,
        label = gang.label,
        isboss = g.isboss or false,
        grade = { level = grade, name = g.name },
    }
end

---Fill in defaults for a fresh or partially-saved character
local function normalize(data)
    local cfg = ArcaConfig.Player
    data.money = data.money or {}
    for _, mType in ipairs(cfg.MoneyTypes) do
        data.money[mType] = data.money[mType] or cfg.Money[mType] or 0
    end
    data.charinfo = data.charinfo or {}
    data.metadata = data.metadata or {}
    for k, v in pairs(cfg.DefaultMetadata) do
        if data.metadata[k] == nil then data.metadata[k] = Arca.Shared.Copy(v) end
    end
    data.job = buildJob(data.job and data.job.name, data.job and data.job.grade and data.job.grade.level, data.job and data.job.onduty)
    data.gang = buildGang(data.gang and data.gang.name, data.gang and data.gang.grade and data.gang.grade.level)
    data.position = data.position or {
        x = cfg.DefaultSpawn.x, y = cfg.DefaultSpawn.y, z = cfg.DefaultSpawn.z, w = cfg.DefaultSpawn.w,
    }
    return data
end

---Builds the player object around PlayerData and registers it
local function createPlayer(PlayerData)
    local self = {}
    self.PlayerData = PlayerData
    self.Functions = {} -- qb-style alias, methods live on both
    local src = PlayerData.source

    local function sync()
        TriggerClientEvent('arca_core:client:setPlayerData', src, self.PlayerData)
        TriggerEvent('arca_core:server:playerDataUpdated', src, self.PlayerData)
    end

    function self.UpdatePlayerData() sync() end

    function self.SetJob(name, grade)
        if not Arca.Shared.Jobs[name] then return false end
        self.PlayerData.job = buildJob(name, grade)
        sync()
        TriggerEvent('arca_core:server:onJobUpdate', src, self.PlayerData.job)
        TriggerClientEvent('arca_core:client:onJobUpdate', src, self.PlayerData.job)
        return true
    end

    function self.SetJobDuty(onduty)
        self.PlayerData.job.onduty = not not onduty
        sync()
        TriggerEvent('arca_core:server:setDuty', src, self.PlayerData.job.onduty)
        TriggerClientEvent('arca_core:client:setDuty', src, self.PlayerData.job.onduty)
    end

    function self.SetGang(name, grade)
        if not Arca.Shared.Gangs[name] then return false end
        self.PlayerData.gang = buildGang(name, grade)
        sync()
        TriggerEvent('arca_core:server:onGangUpdate', src, self.PlayerData.gang)
        TriggerClientEvent('arca_core:client:onGangUpdate', src, self.PlayerData.gang)
        return true
    end

    local function changeMoney(mType, amount, reason, op)
        amount = tonumber(amount)
        if not amount or amount < 0 then return false end
        local money = self.PlayerData.money
        if money[mType] == nil then return false end
        local old = money[mType]
        if op == 'add' then
            money[mType] = old + amount
        elseif op == 'remove' then
            if old < amount then return false end
            money[mType] = old - amount
        else
            money[mType] = amount
        end
        sync()
        TriggerEvent('arca_core:server:onMoneyChange', src, mType, money[mType] - old, reason or 'unknown', op)
        TriggerClientEvent('arca_core:client:onMoneyChange', src, mType, money[mType] - old, reason, op)
        return true
    end

    function self.AddMoney(mType, amount, reason) return changeMoney(mType, amount, reason, 'add') end
    function self.RemoveMoney(mType, amount, reason) return changeMoney(mType, amount, reason, 'remove') end
    function self.SetMoney(mType, amount, reason) return changeMoney(mType, amount, reason, 'set') end
    function self.GetMoney(mType) return self.PlayerData.money[mType] end

    function self.SetMetaData(key, value)
        self.PlayerData.metadata[key] = value
        sync()
    end

    function self.GetMetaData(key)
        return self.PlayerData.metadata[key]
    end

    function self.SetCharInfo(key, value)
        self.PlayerData.charinfo[key] = value
        sync()
    end

    function self.Save()
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            self.PlayerData.position = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
        end
        local pd = self.PlayerData
        MySQL.prepare.await([[
            UPDATE players SET name = ?, money = ?, charinfo = ?, job = ?, gang = ?, position = ?, metadata = ?
            WHERE citizenid = ?
        ]], {
            GetPlayerName(src) or pd.name,
            json.encode(pd.money), json.encode(pd.charinfo), json.encode(pd.job),
            json.encode(pd.gang), json.encode(pd.position), json.encode(pd.metadata),
            pd.citizenid,
        })
        Arca.Debug('saved', pd.citizenid)
    end

    function self.Logout()
        Arca.Player.Logout(src)
    end

    -- bridges (e.g. bridge/qb) add their own methods/fields here
    for _, extend in ipairs(Arca.Player.Extensions) do extend(self) end

    for k, v in pairs(self) do
        if type(v) == 'function' then self.Functions[k] = v end
    end

    Arca.Players[src] = self
    sync()
    return self
end

---Returns all characters for the player's license (for arca_character)
---@param source number
function Arca.Player.GetCharacters(source)
    local license = Arca.Functions.GetIdentifier(source)
    local rows = MySQL.query.await('SELECT * FROM players WHERE license = ? ORDER BY cid', { license }) or {}
    for i = 1, #rows do
        local r = rows[i]
        r.money = decode(r.money, {})
        r.charinfo = decode(r.charinfo, {})
        r.job = decode(r.job, nil)
        r.gang = decode(r.gang, nil)
        r.position = decode(r.position, nil)
        r.metadata = decode(r.metadata, {})
    end
    return rows
end

---Log a player in to an existing character, or create a new one.
---@param source number
---@param citizenid? string existing character
---@param newData? { cid: number, charinfo: table } new character
---@return table|false player
function Arca.Player.Login(source, citizenid, newData)
    source = tonumber(source)
    if not source or Arca.Players[source] then return false end
    local license = Arca.Functions.GetIdentifier(source)
    if not license then
        DropPlayer(tostring(source), 'No license identifier found')
        return false
    end

    local data
    if citizenid then
        local row = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', { citizenid })
        if not row or row.license ~= license then
            print(('^1[arca_core] %s tried to load character %s they do not own^7'):format(license, citizenid))
            return false
        end
        data = {
            citizenid = row.citizenid,
            cid = row.cid,
            money = decode(row.money, nil),
            charinfo = decode(row.charinfo, nil),
            job = decode(row.job, nil),
            gang = decode(row.gang, nil),
            position = decode(row.position, nil),
            metadata = decode(row.metadata, nil),
        }
    elseif newData then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE license = ?', { license }) or 0
        if count >= ArcaConfig.Server.MaxCharacters then return false end
        if newData.cid and MySQL.scalar.await('SELECT 1 FROM players WHERE license = ? AND cid = ?', { license, newData.cid }) then
            return false
        end
        data = normalize({ citizenid = generateCitizenId(), cid = newData.cid or count + 1, charinfo = newData.charinfo })
        data.charinfo.phone = data.charinfo.phone or Arca.Shared.RandomInt(10)
        MySQL.insert.await([[
            INSERT INTO players (citizenid, cid, license, name, money, charinfo, job, gang, position, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            data.citizenid, data.cid, license, GetPlayerName(source),
            json.encode(data.money), json.encode(data.charinfo), json.encode(data.job),
            json.encode(data.gang), json.encode(data.position), json.encode(data.metadata),
        })
    else
        return false
    end

    data = normalize(data)
    data.source = source
    data.license = license
    data.name = GetPlayerName(source)

    local player = createPlayer(data)
    Arca.Debug('loaded', data.citizenid, 'for', source)
    TriggerEvent('arca_core:server:playerLoaded', player)
    TriggerClientEvent('arca_core:client:playerLoaded', source, player.PlayerData)
    return player
end

---@param source number
function Arca.Player.Logout(source)
    local player = Arca.Players[source]
    if not player then return end
    player.Save()
    Arca.Players[source] = nil
    TriggerEvent('arca_core:server:playerUnloaded', source)
    TriggerClientEvent('arca_core:client:playerUnloaded', source)
end

---@param source number
---@param citizenid string
function Arca.Player.DeleteCharacter(source, citizenid)
    local license = Arca.Functions.GetIdentifier(source)
    local affected = MySQL.update.await('DELETE FROM players WHERE citizenid = ? AND license = ?', { citizenid, license })
    if affected and affected > 0 then
        TriggerEvent('arca_core:server:characterDeleted', source, citizenid)
        return true
    end
    return false
end

---Saves everyone; used by the save loop and on resource stop
function Arca.Player.SaveAll()
    for _, player in pairs(Arca.Players) do player.Save() end
end

exports('Login', Arca.Player.Login)
exports('Logout', Arca.Player.Logout)
exports('GetCharacters', Arca.Player.GetCharacters)
exports('DeleteCharacter', Arca.Player.DeleteCharacter)
