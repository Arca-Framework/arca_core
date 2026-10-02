-- Tracks which UI modules want NUI focus so one closing doesn't steal focus from another
Arca.Nui = {}

local holders = {}

---@param owner string
---@param hasFocus boolean
---@param hasCursor? boolean
function Arca.Nui.SetFocus(owner, hasFocus, hasCursor)
    holders[owner] = hasFocus and (hasCursor ~= false) or nil
    local focus, cursor = false, false
    for _, c in pairs(holders) do
        focus = true
        cursor = cursor or c
    end
    SetNuiFocus(focus, cursor)
end
