Arca.Callback = {}

local callbacks = {}
local pending = {}
local requestId = 0

---Register a callback the server can trigger with Arca.Callback.Await
---@param name string
---@param fn fun(...): ...
function Arca.Callback.Register(name, fn)
    callbacks[name] = fn
end

---Request data from the server and wait for it
---@param name string
function Arca.Callback.Await(name, ...)
    requestId = requestId + 1
    local id = requestId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('arca_core:cb:server', name, id, ...)

    SetTimeout(10000, function()
        if pending[id] then
            pending[id] = nil
            print(('^3[arca_core] callback "%s" timed out^7'):format(name))
            p:resolve({ n = 0 })
        end
    end)

    local res = Citizen.Await(p)
    return table.unpack(res, 1, res.n)
end

---Non-blocking variant
function Arca.Callback.Trigger(name, cb, ...)
    local args = table.pack(...)
    CreateThread(function()
        cb(Arca.Callback.Await(name, table.unpack(args, 1, args.n)))
    end)
end

RegisterNetEvent('arca_core:cb:clientResponse', function(id, ok, ...)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    if ok then
        p:resolve(table.pack(...))
    else
        print(('^3[arca_core] callback failed: %s^7'):format((...)))
        p:resolve({ n = 0 })
    end
end)

RegisterNetEvent('arca_core:cb:client', function(name, id, ...)
    local fn = callbacks[name]
    if not fn then
        TriggerServerEvent('arca_core:cb:serverResponse', id, false, ('callback "%s" does not exist'):format(name))
        return
    end
    local result = table.pack(pcall(fn, ...))
    if not result[1] then
        TriggerServerEvent('arca_core:cb:serverResponse', id, false, tostring(result[2]))
        return
    end
    TriggerServerEvent('arca_core:cb:serverResponse', id, true, table.unpack(result, 2, result.n))
end)
