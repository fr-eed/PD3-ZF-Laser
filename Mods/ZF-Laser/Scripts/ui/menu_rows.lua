-- The rows of the mod's settings section, as data.
local Rows = {}

Rows.Toggles = {
    { Name = "ZFLaser_Enabled", Label = "Laser sight",
      Get = function(C) return C.Enabled end, Set = function(C, V) C.Enabled = V end },
    { Name = "ZFLaser_Sound", Label = "Laser on/off sound",
      Get = function(C) return C.Sound.Enabled end, Set = function(C, V) C.Sound.Enabled = V end },
    { Name = "ZFLaser_Zeroing", Label = "Laser zeroed to crosshair",
      Get = function(C) return C.Zeroing.ToAim end, Set = function(C, V) C.Zeroing.ToAim = V end },
}

-- Brightness sliders show a 0-100 level on a square curve for a finer tuning of low brightness lasers.
local MaxBrightness = 500.0
local function LevelToBrightness(Level) return MaxBrightness * (Level / 100.0) ^ 2 end
local function BrightnessToLevel(Value) return 100.0 * math.sqrt(math.max(0.0, Value) / MaxBrightness) end

Rows.Sliders = {
    { Name = "ZFLaser_Hue", Label = "Laser color (hue)", Min = 0.0, Max = 360.0, Step = 10.0, Tint = true,
      Get = function(C) return C.Hue end, Set = function(C, V) C.Hue = V end },
    { Name = "ZFLaser_Brightness", Label = "Laser brightness", Min = 0.0, Max = 100.0, Step = 1.0,
      Get = function(C) return BrightnessToLevel(C.Brightness) end,
      Set = function(C, V) C.Brightness = LevelToBrightness(V) end },
    { Name = "ZFLaser_DotBrightness", Label = "Laser dot brightness", Min = 0.0, Max = 100.0, Step = 1.0,
      Get = function(C) return BrightnessToLevel(C.Dot.Brightness) end,
      Set = function(C, V) C.Dot.Brightness = LevelToBrightness(V) end },
    { Name = "ZFLaser_Dot", Label = "Laser dot size (mm)", Min = 5.0, Max = 40.0, Step = 5.0,
      Get = function(C) return C.Dot.Size * 1000.0 end, Set = function(C, V) C.Dot.Size = V / 1000.0 end },
    { Name = "ZFLaser_Forward", Label = "Laser forward (mm from muzzle)", Min = -400.0, Max = 400.0, Step = 10.0,
      Get = function(C) return C.Mount.Forward * 10.0 end, Set = function(C, V) C.Mount.Forward = V / 10.0 end },
    { Name = "ZFLaser_Up", Label = "Laser height (mm from bore)", Min = -60.0, Max = 60.0, Step = 5.0,
      Get = function(C) return C.Mount.Up * 10.0 end, Set = function(C, V) C.Mount.Up = V / 10.0 end },
    { Name = "ZFLaser_Right", Label = "Laser side (mm from bore)", Min = -60.0, Max = 60.0, Step = 5.0,
      Get = function(C) return C.Mount.Right * 10.0 end, Set = function(C, V) C.Mount.Right = V / 10.0 end },
    { Name = "ZFLaser_Zero", Label = "Laser zero distance (m, crosshair zeroing off)", Min = 5.0, Max = 100.0, Step = 5.0,
      Get = function(C) return C.Mount.Zero end, Set = function(C, V) C.Mount.Zero = V end },
}

Rows.Reset = { Name = "ZFLaser_Reset", Label = "Laser defaults" }

return Rows
