-- Vectors as { X, Y, Z } and rotators as { Pitch, Yaw, Roll } in degrees,
-- Unreal Engine's convention: X forward, Y right, Z up.
local Vec = {}

function Vec.Dot(A, B) return A.X * B.X + A.Y * B.Y + A.Z * B.Z end

function Vec.Add(A, B) return { X = A.X + B.X, Y = A.Y + B.Y, Z = A.Z + B.Z } end

function Vec.Sub(A, B) return { X = A.X - B.X, Y = A.Y - B.Y, Z = A.Z - B.Z } end

function Vec.Scale(A, K) return { X = A.X * K, Y = A.Y * K, Z = A.Z * K } end

function Vec.Normalized(V)
    local Length = math.sqrt(Vec.Dot(V, V))
    if Length < 1e-6 then return { X = 1.0, Y = 0.0, Z = 0.0 } end
    return Vec.Scale(V, 1.0 / Length)
end

-- Degrees between two unit vectors.
function Vec.Angle(A, B)
    local D = math.max(-1.0, math.min(1.0, Vec.Dot(A, B)))
    return math.deg(math.acos(D))
end

function Vec.Same(A, B) return A.X == B.X and A.Y == B.Y and A.Z == B.Z end

-- A + (B - A) * T
function Vec.Lerp(A, B, T)
    return { X = A.X + (B.X - A.X) * T, Y = A.Y + (B.Y - A.Y) * T, Z = A.Z + (B.Z - A.Z) * T }
end

-- Unit vector from pitch and yaw in radians.
function Vec.FromAngles(Pitch, Yaw)
    return { X = math.cos(Pitch) * math.cos(Yaw), Y = math.cos(Pitch) * math.sin(Yaw), Z = math.sin(Pitch) }
end

-- Pitch and yaw of a unit vector, in degrees.
function Vec.PitchYaw(D)
    return math.deg(math.asin(D.Z)), math.deg(math.atan(D.Y, D.X))
end

-- Rotator whose forward is the given unit vector.
function Vec.ToRotator(D)
    local Pitch, Yaw = Vec.PitchYaw(D)
    return { Pitch = Pitch, Yaw = Yaw, Roll = 0.0 }
end

-- The three unit axes of a rotator: forward, right, up.
function Vec.AxesOf(Rot)
    local SP, CP = math.sin(math.rad(Rot.Pitch)), math.cos(math.rad(Rot.Pitch))
    local SY, CY = math.sin(math.rad(Rot.Yaw)), math.cos(math.rad(Rot.Yaw))
    local SR, CR = math.sin(math.rad(Rot.Roll)), math.cos(math.rad(Rot.Roll))
    return { X = CP * CY, Y = CP * SY, Z = SP },
           { X = SR * SP * CY - CR * SY, Y = SR * SP * SY + CR * CY, Z = -SR * CP },
           { X = -(CR * SP * CY + SR * SY), Y = CY * SR - CR * SP * SY, Z = CR * CP }
end

-- Frame = { X, Y, Z } axes plus an Origin. Local to world and back.
function Vec.ToWorld(Frame, Local)
    return {
        X = Frame.Origin.X + Frame.X.X * Local.X + Frame.Y.X * Local.Y + Frame.Z.X * Local.Z,
        Y = Frame.Origin.Y + Frame.X.Y * Local.X + Frame.Y.Y * Local.Y + Frame.Z.Y * Local.Z,
        Z = Frame.Origin.Z + Frame.X.Z * Local.X + Frame.Y.Z * Local.Y + Frame.Z.Z * Local.Z,
    }
end

function Vec.ToLocal(Frame, World)
    local D = Vec.Sub(World, Frame.Origin)
    return { X = Vec.Dot(D, Frame.X), Y = Vec.Dot(D, Frame.Y), Z = Vec.Dot(D, Frame.Z) }
end

-- Directions ignore the origin.
function Vec.DirToWorld(Frame, Local)
    return {
        X = Frame.X.X * Local.X + Frame.Y.X * Local.Y + Frame.Z.X * Local.Z,
        Y = Frame.X.Y * Local.X + Frame.Y.Y * Local.Y + Frame.Z.Y * Local.Z,
        Z = Frame.X.Z * Local.X + Frame.Y.Z * Local.Y + Frame.Z.Z * Local.Z,
    }
end

function Vec.Frame(Origin, Rot)
    local X, Y, Z = Vec.AxesOf(Rot)
    return { Origin = Origin, X = X, Y = Y, Z = Z }
end

return Vec
