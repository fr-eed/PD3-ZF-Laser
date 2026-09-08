-- Development aids. Not needed by the mod: main.lua loads this file only if it exists
--   6 -- log the offset between the beam and the aim line for every laser that is on,
-- as the pitch and yaw a Weapons Bore entry in config.lua would need
--
-- Every N num of seconds a health line: Lua heap before and after a full collection,
-- lasers alive, frames per second and the longest frame.
local Game = require("engine.game")
local Zeroing = require("core.zeroing")

local Dev = {}

-- Last aim target per laser, kept weakly so lasers can be collected.
local Targets = setmetatable({}, { __mode = "k" })

local Every = 60.0 * 5   -- seconds between health lines
local Clock = 0.0    -- seconds since the last health line
local Frames = 0     -- frames since the last health line
local Longest = 0.0  -- longest frame since the last health line, seconds

-- Called by main.lua every frame the character exists.
function Dev.Frame(Player, Lasers)
    local Delta = Game.DeltaSeconds(Player)
    Clock = Clock + Delta
    Frames = Frames + 1
    if Delta > Longest then Longest = Delta end
    if Clock < Every then return end
    local Alive = 0
    for _ in pairs(Lasers) do Alive = Alive + 1 end
    local Before = collectgarbage("count") / 1024
    collectgarbage("collect")
    local After = collectgarbage("count") / 1024
    Game.Log("health: lua heap %.1f MB, %.1f MB after collect, %d lasers alive, %.0f fps, longest frame %.0f ms",
        Before, After, Alive, Frames / Clock, Longest * 1000)
    Clock, Frames, Longest = 0.0, 0, 0.0
end

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
    Game.Log("Dev mode on. Press 6 to see offsets. Health line print every %.0f s", Every)
end

return Dev
