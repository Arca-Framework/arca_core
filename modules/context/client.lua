---@class ArcaContextOption
---@field title string
---@field description? string
---@field icon? string font awesome class, e.g. 'fa-solid fa-car'
---@field disabled? boolean
---@field menu? string id of a submenu to open
---@field onSelect? fun(args: any)
---@field event? string client event
---@field serverEvent? string
---@field args? any
---@field metadata? table<string, any> shown as key/value lines

---@class ArcaContextMenu
---@field id string
---@field title string
---@field menu? string parent menu id (adds a back button)
---@field canClose? boolean default true
---@field onExit? fun()
---@field options ArcaContextOption[]

local menus = {}
local openId

---@param menu ArcaContextMenu|ArcaContextMenu[]
function Arca.RegisterContext(menu)
    if menu.id then
        menus[menu.id] = menu
    else
        for i = 1, #menu do menus[menu[i].id] = menu[i] end
    end
end

---@param id string
function Arca.ShowContext(id)
    local menu = menus[id]
    if not menu then return print(('^1[arca_core] context "%s" not registered^7'):format(id)) end
    openId = id

    local options = {}
    for i, opt in ipairs(menu.options) do
        local meta
        if opt.metadata then
            meta = {}
            for k, v in pairs(opt.metadata) do meta[#meta + 1] = { label = tostring(k), value = tostring(v) } end
        end
        options[i] = {
            title = opt.title,
            description = opt.description,
            icon = opt.icon,
            disabled = opt.disabled,
            arrow = opt.menu ~= nil,
            metadata = meta,
        }
    end

    SendNUIMessage({
        action = 'context',
        data = { title = menu.title, back = menu.menu ~= nil, canClose = menu.canClose ~= false, options = options },
    })
    Arca.Nui.SetFocus('context', true)
end

function Arca.HideContext(runExit)
    if not openId then return end
    local menu = menus[openId]
    openId = nil
    SendNUIMessage({ action = 'contextHide' })
    Arca.Nui.SetFocus('context', false)
    if runExit and menu and menu.onExit then menu.onExit() end
end

function Arca.GetOpenContext() return openId end

RegisterNUICallback('context:select', function(data, cb)
    cb(1)
    local menu = openId and menus[openId]
    local opt = menu and menu.options[tonumber(data.index)]
    if not opt or opt.disabled then return end

    if opt.menu then
        return Arca.ShowContext(opt.menu)
    end

    Arca.HideContext(false)
    if opt.onSelect then opt.onSelect(opt.args) end
    if opt.event then TriggerEvent(opt.event, opt.args) end
    if opt.serverEvent then TriggerServerEvent(opt.serverEvent, opt.args) end
end)

RegisterNUICallback('context:back', function(_, cb)
    cb(1)
    local menu = openId and menus[openId]
    if menu and menu.menu then Arca.ShowContext(menu.menu) end
end)

RegisterNUICallback('context:close', function(_, cb)
    cb(1)
    local menu = openId and menus[openId]
    if menu and menu.canClose == false then return end
    Arca.HideContext(true)
end)

exports('RegisterContext', Arca.RegisterContext)
exports('ShowContext', Arca.ShowContext)
exports('HideContext', Arca.HideContext)
exports('GetOpenContext', Arca.GetOpenContext)
