-- qb-core compatibility: shared tables and helpers.
-- The Arca core object doubles as the QBCore object, so this only fills in
-- names qb resources expect that Arca doesn't already have.
if not ArcaConfig.Bridge.qb then return end

local Shared = Arca.Shared

-- Filled by your inventory/vehicle resources (or paste qb-core's shared files in)
Shared.Items = Shared.Items or {}
Shared.Vehicles = Shared.Vehicles or {}
Shared.VehicleHashes = Shared.VehicleHashes or {}
Shared.Weapons = Shared.Weapons or {}
Shared.Locations = Shared.Locations or {}
Shared.StarterItems = Shared.StarterItems or {}
Shared.ForceJobDefaultDutyAtLogin = true

function Shared.SplitStr(str, delimiter)
    local result = {}
    local from = 1
    local delimFrom, delimTo = string.find(str, delimiter, from, true)
    while delimFrom do
        result[#result + 1] = string.sub(str, from, delimFrom - 1)
        from = delimTo + 1
        delimFrom, delimTo = string.find(str, delimiter, from, true)
    end
    result[#result + 1] = string.sub(str, from)
    return result
end

function Shared.ChangeVehicleExtra(vehicle, extra, enable)
    if DoesExtraExist(vehicle, extra) then
        SetVehicleExtra(vehicle, extra, not enable)
    end
end

function Shared.SetDefaultVehicleExtras(vehicle, config)
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then SetVehicleExtra(vehicle, i, true) end
    end
    for id, enabled in pairs(config or {}) do
        Shared.ChangeVehicleExtra(vehicle, tonumber(id), type(enabled) == 'boolean' and enabled or true)
    end
end

-- qb notify types -> Arca notify types
Arca.QBNotifyTypes = {
    primary = 'inform',
    police = 'inform',
    ambulance = 'inform',
    success = 'success',
    error = 'error',
    warning = 'warning',
}

---Converts qb Notify(text, type, length) arguments to Arca's format
function Arca.QBNotifyArgs(text, nType, length)
    local data = type(text) == 'table'
        and { title = text.caption and text.text or nil, description = text.caption or text.text }
        or { description = text }
    data.type = Arca.QBNotifyTypes[nType] or nType or 'inform'
    data.duration = length
    return data
end

Arca.Config.Money = Arca.Config.Money or { MoneyTypes = {}, DontAllowMinus = { 'cash', 'crypto' } }
for _, mType in ipairs(ArcaConfig.Player.MoneyTypes) do
    Arca.Config.Money.MoneyTypes[mType] = ArcaConfig.Player.Money[mType] or 0
end
