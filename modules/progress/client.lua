---@class ArcaProgressData
---@field duration number ms
---@field label string
---@field canCancel? boolean
---@field useWhileDead? boolean
---@field disable? { move?: boolean, car?: boolean, combat?: boolean, mouse?: boolean }
---@field anim? { dict?: string, clip?: string, flag?: number, scenario?: string }
---@field prop? { model: string|number, bone?: number, pos?: vector3, rot?: vector3 }

local active

local function disableControls(disable)
    if disable.move then
        DisableControlAction(0, 30, true) -- move LR
        DisableControlAction(0, 31, true) -- move UD
        DisableControlAction(0, 21, true) -- sprint
        DisableControlAction(0, 22, true) -- jump
        DisableControlAction(0, 36, true) -- duck
    end
    if disable.car then
        DisableControlAction(0, 63, true)
        DisableControlAction(0, 64, true)
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
        DisableControlAction(0, 75, true) -- exit vehicle
    end
    if disable.combat then
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 37, true)
        DisableControlAction(0, 47, true)
        DisableControlAction(0, 58, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 143, true)
        DisableControlAction(0, 257, true)
        DisableControlAction(0, 263, true)
        DisableControlAction(0, 264, true)
    end
    if disable.mouse then
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        DisableControlAction(0, 106, true)
    end
end

---Show a progress bar and block until it finishes.
---@param data ArcaProgressData
---@return boolean completed false if cancelled
function Arca.Progress(data)
    if active then return false end
    active = { cancelled = false }

    local ped = PlayerPedId()
    local prop

    if data.anim then
        if data.anim.scenario then
            TaskStartScenarioInPlace(ped, data.anim.scenario, 0, true)
        elseif data.anim.dict and Arca.Functions.LoadAnimDict(data.anim.dict) then
            TaskPlayAnim(ped, data.anim.dict, data.anim.clip, 3.0, 3.0, -1, data.anim.flag or 49, 0, false, false, false)
        end
    end

    if data.prop then
        local model = Arca.Functions.LoadModel(data.prop.model)
        if model then
            local c = GetEntityCoords(ped)
            prop = CreateObject(model, c.x, c.y, c.z, true, true, false)
            local pos = data.prop.pos or vec3(0, 0, 0)
            local rot = data.prop.rot or vec3(0, 0, 0)
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, data.prop.bone or 60309),
                pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 0, true)
            SetModelAsNoLongerNeeded(model)
        end
    end

    SendNUIMessage({ action = 'progress', data = { label = data.label, duration = data.duration } })

    local disable = data.disable or {}
    local endTime = GetGameTimer() + data.duration
    while GetGameTimer() < endTime do
        disableControls(disable)
        if data.canCancel and IsControlJustPressed(0, ArcaConfig.Progress.CancelKey) then
            active.cancelled = true
        end
        if not data.useWhileDead and IsEntityDead(ped) then
            active.cancelled = true
        end
        if active.cancelled then break end
        Wait(0)
    end

    local cancelled = active.cancelled
    if data.anim then
        if data.anim.scenario then
            ClearPedTasks(ped)
        elseif data.anim.dict then
            StopAnimTask(ped, data.anim.dict, data.anim.clip, 1.0)
        end
    end
    if prop then DeleteEntity(prop) end

    SendNUIMessage({ action = 'progressEnd', data = { cancelled = cancelled } })
    active = nil
    return not cancelled
end

function Arca.ProgressActive() return active ~= nil end

function Arca.CancelProgress()
    if active then active.cancelled = true end
end

exports('Progress', Arca.Progress)
exports('ProgressActive', Arca.ProgressActive)
exports('CancelProgress', Arca.CancelProgress)
