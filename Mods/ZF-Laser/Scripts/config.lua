-- Defaults. In-game changes are saved to settings.lua beside this file.
local Config = {
    Enabled = true,
    Key = "ZERO",            -- toggles the laser
    Brightness = 0.8,        -- HDR, additive. Can be set to 0 for only visible Dot
    Hue = 0.0,               -- degrees: 0 red, 120 green, 240 blue; beam and dot
    Segment = { Length = 1.0, Thickness = 0.0025, Count = 8 },   -- meters; reach is Length * Count
    -- Emitter offset from the muzzle socket in cm; Zero is where the beam
    -- meets the bore line (m) when crosshair zeroing is off.
    Mount = { Forward = -30.0, Right = 0.0, Up = -2.0, Zero = 15.0 },
    Dot = { Size = 0.02, Lift = 1.0, Brightness = 6.05 },   -- sphere, meters; lift in cm
    -- Steer the beam onto the crosshair's hit point while the barrel is within
    -- MaxAngle degrees of it, averaged over Time seconds. See core/zeroing.lua.
    Zeroing = { ToAim = true, MaxAngle = 6.0, Time = 0.4 },
    -- Per-weapon overrides by class name (the log prints it on spawn): any of
    -- Enabled, Mount, Zeroing, Bore. Bore is a fixed pitch/yaw offset in
    -- degrees. dev.lua's key 6 measures it.
    -- Other weapons can be added once their viewmodel misaligment is discovered.
    Weapons = {
        -- Hip-fired M135 Arges.
        -- Has a wildly misaligned viewmodel, most likely done for better visuals but.
        -- Because of this laser should point at an angle
        ["BP_RangedWeapon_OVK_ARGES_C"] = {
            Zeroing = { MaxAngle = 20.0 },
            Bore = { Pitch = -8.5, Yaw = 0.1 },
        },
    },
    -- Wwise event played when the laser turns on or off, as package and event
    -- name. Currently the cutting tool's on-switch foley.
    -- Other candidates: Gen_Speaker_Switch, PLR_Int_Hit_ElectronicBox_Switch,
    -- Player_Phone_KB_Click, UI_Gen_Click under /Game/WwiseAudio/Events.
    Sound = {
        Enabled = true,
        Package = "/Game/WwiseAudio/Events/Gear/Cutting_Tool/Foley/FOL_Cutting_Tool_On_Switch",
        Event = "FOL_Cutting_Tool_On_Switch",
    },
}

local function Log(fmt, ...)
    print(string.format("[ZF-Laser] " .. fmt .. "\n", ...))
end

local SettingsPath = nil
do
    local Info = debug and debug.getinfo and debug.getinfo(1, "S")
    local Source = Info and Info.source or ""
    local Dir = Source:match("^@(.*[/\\])")
    if Dir then SettingsPath = Dir .. "settings.lua" end
end

local function Serialize(Value, Indent)
    if type(Value) == "table" then
        local Lines = {}
        for Name, Item in pairs(Value) do
            Lines[#Lines + 1] = Indent .. "    " .. Name .. " = " .. Serialize(Item, Indent .. "    ") .. ","
        end
        table.sort(Lines)
        return "{\n" .. table.concat(Lines, "\n") .. "\n" .. Indent .. "}"
    elseif type(Value) == "string" then
        return string.format("%q", Value)
    end
    return tostring(Value)
end

local function Merge(Into, From)
    for Name, Item in pairs(From) do
        if type(Item) == "table" and type(Into[Name]) == "table" then
            Merge(Into[Name], Item)
        elseif Into[Name] ~= nil then
            Into[Name] = Item
        end
    end
end

-- Snapshot of the values above, taken before settings.lua is merged in.
local Defaults = {}
local function Snapshot(From, Into)
    for Name, Item in pairs(From) do
        if type(Item) == "table" then
            Into[Name] = {}
            Snapshot(Item, Into[Name])
        elseif type(Item) ~= "function" then
            Into[Name] = Item
        end
    end
end
Snapshot(Config, Defaults)

function Config.Reset()
    Merge(Config, Defaults)
    Config.Save()
end

function Config.Load()
    if not SettingsPath then return end
    local Chunk = loadfile(SettingsPath)
    if not Chunk then return end
    local Ok, Saved = pcall(Chunk)
    if Ok and type(Saved) == "table" then Merge(Config, Saved) end
end

-- Only what can change in game is saved, so edits to this file always apply.
local Persisted = {
    "Enabled", "Sound.Enabled",
    "Brightness", "Hue", "Mount.Forward", "Mount.Up", "Mount.Right", "Mount.Zero", "Dot.Size",
    "Dot.Brightness", "Zeroing.ToAim",
}

-- Copies one dotted path, such as "Sound.Enabled", from Config into Plain.
local function CopyPath(Path, Plain)
    local From, Into = Config, Plain
    for Part in Path:gmatch("[^.]+") do
        if type(From[Part]) == "table" then
            Into[Part] = Into[Part] or {}
            From, Into = From[Part], Into[Part]
        else
            Into[Part] = From[Part]
        end
    end
end

function Config.Save()
    if not SettingsPath then return Log("no settings path; not saved") end
    local Plain = {}
    for _, Path in ipairs(Persisted) do CopyPath(Path, Plain) end
    local File, Err = io.open(SettingsPath, "w")
    if not File then return Log("could not save settings: %s", tostring(Err)) end
    File:write("return " .. Serialize(Plain, "") .. "\n")
    File:close()
end

return Config
