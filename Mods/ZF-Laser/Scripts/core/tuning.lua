-- Settings for the laser lasers with
-- Also takse overided from Config.Weapons if exist
local Tuning = {}

-- A copy of Base one level deep, with Override's fields
local function Overlay(Base, Override)
    local Out = {}
    for Name, Value in pairs(Base) do Out[Name] = Value end
    for Name, Value in pairs(Override or {}) do Out[Name] = Value end
    return Out
end

function Tuning.For(Config, ClassName)
    local Own = Config.Weapons[ClassName] or {}
    return {
        Enabled = Own.Enabled ~= false,
        Mount = Overlay(Config.Mount, Own.Mount),
        Zeroing = Overlay(Config.Zeroing, Own.Zeroing),
        Bore = Overlay({ Pitch = 0.0, Yaw = 0.0 }, Own.Bore),
    }
end

return Tuning
