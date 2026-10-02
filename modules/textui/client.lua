local isOpen, currentText = false, nil

---@param text string supports [E] style key hints
---@param options? { position?: string, icon?: string }
function Arca.ShowTextUI(text, options)
    if isOpen and currentText == text then return end
    options = options or {}
    isOpen, currentText = true, text
    SendNUIMessage({
        action = 'textui',
        data = { text = text, icon = options.icon, position = options.position or ArcaConfig.TextUI.Position },
    })
end

function Arca.HideTextUI()
    if not isOpen then return end
    isOpen, currentText = false, nil
    SendNUIMessage({ action = 'textuiHide' })
end

---@return boolean, string?
function Arca.IsTextUIOpen() return isOpen, currentText end

exports('ShowTextUI', Arca.ShowTextUI)
exports('HideTextUI', Arca.HideTextUI)
exports('IsTextUIOpen', Arca.IsTextUIOpen)
