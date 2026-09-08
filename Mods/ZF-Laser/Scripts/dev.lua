-- Development aids. Not needed by the mod: main.lua loads this file only if it exists
--   6 -- log the offset between the beam and the aim line for every laser that is on,
-- as the pitch and yaw a Weapons Bore entry in config.lua would need
local Game = require("engine.game")
local Zeroing = require("core.zeroing")

local Dev = {}

-- Last aim target per laser, kept weakly so lasers can be collected.
local Targets = setmetatable({}, { __mode = "k" })

local function ReportOffsets(Lasers)
    for _, Item in pairs(Lasers) do
        local Target = Targets[Item]
        if Item.On and Target then
            local Pitch, Yaw = Zeroing.Offset(Target, Item.Bore)
            Game.Log("%s: aim line is pitch %+.1f, yaw %+.1f degrees from the beam", Item.ClassName, Pitch, Yaw)
        end
    end
end

-- Lasers is main's table of live lasers.
function Dev.Install(Laser, Lasers)
    Laser.OnTarget = function(Item, Target) Targets[Item] = Target end
    RegisterKeyBind(Key.SIX, {}, function() Game.OnGameThread(function() ReportOffsets(Lasers) end) end)
    Game.Log("dev keys on: 6 offsets")
end

return Dev
