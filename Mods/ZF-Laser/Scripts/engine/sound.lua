-- The click played when the laser turns on or off.
local Game = require("engine.game")

local Sound = {}
local Reported = false

function Sound.Play(Config, Weapon)
    local Settings = Config.Sound
    if not Settings.Enabled or Settings.Event == "" then return end
    local Ok, Err = pcall(function()
        local Event = Game.LoadByPath(Settings.Package, Settings.Event)
        if not Event then return Game.Log("sound not found: %s.%s", Settings.Package, Settings.Event) end
        local At = Weapon.Mesh:GetSocketLocation(Game.SocketName(Weapon))
        local Ak = Game.Default("/Script/AkAudio.Default__AkGameplayStatics")
        local Id = Ak:PostEventAtLocation(Event, At, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }, Weapon)
        if not Reported then
            Game.Log("posted %s at the muzzle, playing id %s", Settings.Event, tostring(Id))
            Reported = true
        end
    end)
    if not Ok and not Reported then
        Game.Log("sound error: %s", tostring(Err))
        Reported = true
    end
end

return Sound
