---@class ArcaNotifyData
---@field title? string
---@field description? string
---@field type? 'inform'|'success'|'error'|'warning'
---@field duration? number
---@field position? 'top-right'|'top-left'|'top'|'bottom-right'|'bottom-left'|'bottom'

---@param data ArcaNotifyData|string
---@param nType? string
---@param duration? number
function Arca.Notify(data, nType, duration)
    if type(data) == 'string' then
        data = { description = data, type = nType, duration = duration }
    end
    SendNUIMessage({
        action = 'notify',
        data = {
            title = data.title,
            description = data.description,
            type = Arca.QBNotifyTypes and Arca.QBNotifyTypes[data.type] or data.type or 'inform',
            duration = data.duration or ArcaConfig.Notify.Duration,
            position = data.position or ArcaConfig.Notify.Position,
        },
    })
end

RegisterNetEvent('arca_core:notify', function(data, nType, duration)
    Arca.Notify(data, nType, duration)
end)
