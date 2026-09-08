-- The steering rule for the laser, in the muzzle socket's frame.
local Vec = require("core.vec")

local Zeroing = {}

-- The laser's resting direction
function Zeroing.Bore(Mount, Offset)
    local Yaw = -math.atan(Mount.Right, Mount.Zero * 100.0) + math.rad(Offset.Yaw)
    local Pitch = -math.atan(Mount.Up, Mount.Zero * 100.0) + math.rad(Offset.Pitch)
    return Vec.FromAngles(Pitch, Yaw)
end

-- One frame of steering. Aim is the current direction, Target where the
-- crosshair says the beam should go, Bore the resting direction, all in the
-- gun's frame. Returns the new direction.
function Zeroing.Step(Settings, Aim, Target, Bore, Delta)
    -- Zeroing off, or no camera to aim by: the beam rests on the bore.
    if not Settings.ToAim or not Target then return Bore end

    -- Beyond MaxAngle from the bore the gun by design is not pointing where
    -- it shoots (a reload, an inspect), so the beam goes back to the bore
    -- instead of chasing the crosshair across the screen.
    if Vec.Angle(Target, Bore) > Settings.MaxAngle then Target = Bore end

    -- Time zero snaps. Once the beam is nearly on target it jumps the last
    -- bit exactly: the average below would otherwise move toward the target forever.
    if Settings.Time <= 0.0 or Vec.Angle(Target, Aim) < 0.02 then return Target end

    -- Otherwise an exponential running average with time constant Time: this
    -- frame closes the fraction 1 - exp(-Delta / Time) of the remaining gap,
    -- about two thirds of it after Time seconds. The gun model sways against
    -- the camera as you move, so the correction it would need swings with
    -- it. Chasing that every frame makes the beam fight the sway. which is visually annoying
    -- Averaging lets the sway pass through as beam motion, like a real laser bolted to the gun
    local Blend = 1.0 - math.exp(-Delta / Settings.Time)
    return Vec.Normalized(Vec.Lerp(Aim, Target, Blend))
end

-- Pitch and yaw, in degrees, from the bore to the target: what a weapon's
-- Bore override would need to hold the beam on the aim line.
function Zeroing.Offset(Target, Bore)
    local TargetPitch, TargetYaw = Vec.PitchYaw(Target)
    local BorePitch, BoreYaw = Vec.PitchYaw(Bore)
    return TargetPitch - BorePitch, TargetYaw - BoreYaw
end

return Zeroing
