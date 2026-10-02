---@param source number
---@param data table|string
---@param nType? string
---@param duration? number
function Arca.Notify(source, data, nType, duration)
    TriggerClientEvent('arca_core:notify', source, data, nType, duration)
end
