-- Color from a hue. No game calls.
local Color = {}

-- Hue in degrees, 0 red, 120 green, 240 blue, to fully saturated RGB in 0-1.
function Color.FromHue(Hue)
    local H = (Hue % 360.0) / 60.0
    local X = 1.0 - math.abs(H % 2.0 - 1.0)
    local R, G, B
    if H < 1 then R, G, B = 1.0, X, 0.0
    elseif H < 2 then R, G, B = X, 1.0, 0.0
    elseif H < 3 then R, G, B = 0.0, 1.0, X
    elseif H < 4 then R, G, B = 0.0, X, 1.0
    elseif H < 5 then R, G, B = X, 0.0, 1.0
    else R, G, B = 1.0, 0.0, X end
    return { R = R, G = G, B = B }
end

-- The material's color parameter: hue times brightness, opaque.
function Color.Material(Hue, Brightness)
    local C = Color.FromHue(Hue)
    return { R = C.R * Brightness, G = C.G * Brightness, B = C.B * Brightness, A = 1.0 }
end

return Color
