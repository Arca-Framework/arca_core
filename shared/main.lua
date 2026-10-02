Arca = Arca or {}
Arca.Config = ArcaConfig
Arca.Shared = {}

local IsServer = IsDuplicityVersion()
Arca.IsServer = IsServer

function Arca.Shared.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

function Arca.Shared.Trim(str)
    return (tostring(str):gsub('^%s*(.-)%s*$', '%1'))
end

function Arca.Shared.FirstToUpper(str)
    return (tostring(str):gsub('^%l', string.upper))
end

local charset = {}
for i = 48, 57 do charset[#charset + 1] = string.char(i) end
for i = 65, 90 do charset[#charset + 1] = string.char(i) end

function Arca.Shared.RandomStr(length)
    local out = {}
    for i = 1, length do out[i] = charset[math.random(11, #charset)] end
    return table.concat(out)
end

function Arca.Shared.RandomInt(length)
    local out = {}
    for i = 1, length do out[i] = charset[math.random(1, 10)] end
    return table.concat(out)
end

function Arca.Shared.Copy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = Arca.Shared.Copy(v) end
    return out
end

function Arca.Debug(...)
    if not ArcaConfig.Debug then return end
    print(('^5[arca_core]^7 %s'):format(table.concat({ ... }, ' ')))
end
