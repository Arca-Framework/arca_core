Arca.Callback = {}

local callbacks = {}
local pending = {}
local requestId = 0

---Register a callback the client can trigger with Arca.Callback.Await
---@param name string
---@param fn fun(source: number, ...): ...
function Arca.Callback.Register(name, fn)
    callbacks[name] = fn
end

RegisterNetEvent('arca_core:cb:server', function(name, id, ...)
    local src = source
    local fn = callbacks[name]
    if not fn then
        TriggerClientEvent('arca_core:cb:clientResponse', src, id, false, ('callback "%s" does not exist'):format(name))
        return
    end
    local result = table.pack(pcall(fn, src, ...))
    if not result[1] then
        print(('^1[arca_core] callback "%s" errored: %s^7'):format(name, result[2]))
        TriggerClientEvent('arca_core:cb:clientResponse', src, id, false, 'callback errored')
        return
    end
    TriggerClientEvent('arca_core:cb:clientResponse', src, id, true, table.unpack(result, 2, result.n))
end)

---Ask a client for data and wait for the answer
---@param name string
---@param target number
---@param timeout? number ms, default 10000
function Arca.Callback.Await(name, target, timeout, ...)
    requestId = requestId + 1
    local id = requestId
    local p = promise.new()
    pending[id] = { p = p, target = target }
    TriggerClientEvent('arca_core:cb:client', target, name, id, ...)

    SetTimeout(timeout or 10000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ n = 0 })
        end
    end)

    local res = Citizen.Await(p)
    return table.unpack(res, 1, res.n)
end

RegisterNetEvent('arca_core:cb:serverResponse', function(id, ok, ...)
    local req = pending[id]
    if not req or req.target ~= source then return end
    pending[id] = nil
    if ok then
        req.p:resolve(table.pack(...))
    else
        print(('^3[arca_core] client callback failed: %s^7'):format((...)))
        req.p:resolve({ n = 0 })
    end
end)
