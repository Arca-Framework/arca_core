-- Optional convenience for other resources:
--   shared_script '@arca_core/shared/import.lua'
-- Gives a global `Arca` core object without calling the export manually.
if GetResourceState('arca_core') ~= 'started' and GetCurrentResourceName() ~= 'arca_core' then
    error('arca_core must be started before ' .. GetCurrentResourceName(), 0)
end

Arca = exports.arca_core:GetCoreObject()
