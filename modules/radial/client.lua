---@class ArcaRadialItem
---@field id string
---@field label string
---@field icon? string font awesome class
---@field menu? string id of a submenu registered with Arca.RegisterRadial
---@field onSelect? fun(menuId: string?)
---@field keepOpen? boolean

local globalItems = {}   -- ArcaRadialItem[]
local subMenus = {}      -- [id] = { id, items }
local isOpen, disabled = false, false
local stack = {}         -- submenu navigation history
local shownItems         -- the list currently on screen

local function render()
    local id = stack[#stack]
    shownItems = id and subMenus[id] and subMenus[id].items or globalItems
    local items = {}
    for i, item in ipairs(shownItems) do
        items[i] = { label = item.label, icon = item.icon, arrow = item.menu ~= nil }
    end
    SendNUIMessage({ action = 'radial', data = { items = items, sub = #stack > 0 } })
end

function Arca.OpenRadial()
    if isOpen or disabled or #globalItems == 0 then return end
    if not Arca.Functions.IsLoggedIn() or IsNuiFocused() or IsPauseMenuActive() then return end
    isOpen, stack = true, {}
    render()
    Arca.Nui.SetFocus('radial', true)
end

function Arca.CloseRadial()
    if not isOpen then return end
    isOpen, stack, shownItems = false, {}, nil
    SendNUIMessage({ action = 'radialHide' })
    Arca.Nui.SetFocus('radial', false)
end

---@param items ArcaRadialItem|ArcaRadialItem[]
function Arca.AddRadialItem(items)
    if items.id then items = { items } end
    for _, item in ipairs(items) do
        Arca.RemoveRadialItem(item.id)
        globalItems[#globalItems + 1] = item
    end
    if isOpen and #stack == 0 then render() end
end

---@param id string
function Arca.RemoveRadialItem(id)
    for i = #globalItems, 1, -1 do
        if globalItems[i].id == id then table.remove(globalItems, i) end
    end
end

function Arca.ClearRadialItems() globalItems = {} end

---@param menu { id: string, items: ArcaRadialItem[] }
function Arca.RegisterRadial(menu)
    subMenus[menu.id] = menu
end

---@param state boolean
function Arca.DisableRadial(state)
    disabled = state
    if state then Arca.CloseRadial() end
end

RegisterNUICallback('radial:select', function(data, cb)
    cb(1)
    local item = shownItems and shownItems[tonumber(data.index)]
    if not item then return end
    if item.menu then
        stack[#stack + 1] = item.menu
        return render()
    end
    local menuId = stack[#stack]
    if not item.keepOpen then Arca.CloseRadial() end
    if item.onSelect then item.onSelect(menuId) end
end)

RegisterNUICallback('radial:back', function(_, cb)
    cb(1)
    if #stack > 0 then
        stack[#stack] = nil
        render()
    else
        Arca.CloseRadial()
    end
end)

RegisterNUICallback('radial:close', function(_, cb)
    cb(1)
    Arca.CloseRadial()
end)

RegisterCommand('+arca_radial', function()
    if isOpen then Arca.CloseRadial() else Arca.OpenRadial() end
end, false)
RegisterCommand('-arca_radial', function() end, false)
RegisterKeyMapping('+arca_radial', 'Open radial menu', 'keyboard', ArcaConfig.Radial.Key)

exports('AddRadialItem', Arca.AddRadialItem)
exports('RemoveRadialItem', Arca.RemoveRadialItem)
exports('ClearRadialItems', Arca.ClearRadialItems)
exports('RegisterRadial', Arca.RegisterRadial)
exports('OpenRadial', Arca.OpenRadial)
exports('CloseRadial', Arca.CloseRadial)
exports('DisableRadial', Arca.DisableRadial)
