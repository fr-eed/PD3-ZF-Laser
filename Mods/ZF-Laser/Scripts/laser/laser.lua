-- One weapon's laser: the beam, steered each frame by the zeroing rule, and
-- the dot on whatever the beam hits. Knows nothing about equipping.
local Vec = require("core.vec")
local Game = require("engine.game")
local Visual = require("laser.visual")
local Zeroing = require("core.zeroing")
local Tuning = require("core.tuning")

local Laser = {}
Laser.__index = Laser

Laser.TuningFor = Tuning.For

-- Returns nil if the visual could not be built.
function Laser.New(Weapon, Config)
    local ClassName = Weapon:GetClass():GetFName():ToString()
    local Tune = Tuning.For(Config, ClassName)
    local Socket = Game.SocketName(Weapon)
    local Drawn = Visual.New(Weapon, Socket, Config, Tune.Mount)
    if not Drawn then return nil end
    local Self = setmetatable({
        Weapon = Weapon, Socket = Socket, ClassName = ClassName, Tuning = Tune,
        Visual = Drawn, Config = Config, On = false,
        Bore = Zeroing.Bore(Tune.Mount, Tune.Bore),
    }, Laser)
    Self.Aim = Self.Bore   -- unit direction in the socket frame
    Drawn:LayOut(Self.Aim)
    Game.Log("laser on %s", ClassName)
    return Self
end

function Laser:IsValid()
    return self.Weapon:IsValid() and self.Visual:IsValid()
end

function Laser:SetOn(On)
    if self.On == On then return end
    self.On = On
    self.Visual:SetOn(On)
end

function Laser:Destroy()
    self.Visual:Destroy()
    self.On = false
end

-- The emitter in the world: the muzzle socket plus the mount offset.
function Laser:Emitter(Frame)
    local Mount = self.Tuning.Mount
    return Vec.ToWorld(Frame, { X = Mount.Forward, Y = Mount.Right, Z = Mount.Up })
end

-- Where the camera's aim line lands, as a unit direction from the emitter in
-- the socket's frame, or nil without a camera. A fixed zero distance leaves
-- parallax at other ranges, so the aim line is traced and its hit point used;
-- with nothing in reach, the far end of the beam.
function Laser:AimTarget(Pawn, Camera, Frame, Emitter, Reach)
    if not Camera then return nil end
    local Eye = Camera:GetCameraLocation()
    -- The camera manager still holds last frame's rotation when this runs,
    -- which puts the beam a frame behind every turn. The control rotation
    -- already has this frame's input.
    local Rot = Camera:GetCameraRotation()
    pcall(function() Rot = Pawn.Controller:GetControlRotation() end)
    local Forward = Vec.AxesOf(Rot)
    local Far = Vec.Add(Eye, Vec.Scale(Forward, Reach))
    local Hit = Game.TraceWorld(Pawn, Eye, Far, Game.WeaponActors(self.Weapon))
    local Point = Hit and Hit.ImpactPoint or Far
    return Vec.Normalized(Vec.ToLocal({ Origin = Emitter, X = Frame.X, Y = Frame.Y, Z = Frame.Z }, Point))
end

-- Once per frame while on: steer the beam, then trace along it for the dot.
-- The beam itself is left whole: going through glass and still leaving a dot
-- on it is what a real one does.
function Laser:Update(Pawn, Camera)
    if not self.On or not self.Visual:IsValid() then return end
    -- Follows the gun between passes, so other mods may move the viewmodel.
    self.Visual:SetPass(Visual.GunPass(self.Weapon))
    local Segment = self.Config.Segment
    local Reach = Segment.Length * Segment.Count * 100.0
    local Frame = Game.MuzzleFrame(self.Weapon, self.Socket)
    local Emitter = self:Emitter(Frame)

    local Target = self:AimTarget(Pawn, Camera, Frame, Emitter, Reach)
    if Laser.OnTarget then Laser.OnTarget(self, Target) end   -- dev.lua, if present
    local Next = Zeroing.Step(self.Tuning.Zeroing, self.Aim, Target, self.Bore, Game.DeltaSeconds(self.Weapon))
    if not Vec.Same(Next, self.Aim) then
        self.Aim = Next
        self.Visual:LayOut(Next)
    end

    -- Starts a little ahead of the muzzle so the gun's own barrel and
    -- attachments, which hang off the weapon as separate actors, are skipped.
    local Dir = Vec.DirToWorld(Frame, self.Aim)
    local Start = Vec.Add(Emitter, Vec.Scale(Dir, 10.0))
    local End = Vec.Add(Start, Vec.Scale(Dir, Reach))
    local Ignore = Game.WeaponActors(self.Weapon)
    local Hit = Game.TraceWorld(Pawn, Start, End, Ignore)
    local Person = Game.TracePawns(Pawn, Start, End, Ignore)
    if Person and (not Hit or Person.Distance < Hit.Distance) then Hit = Person end
    if Hit then
        self.Visual:PlaceDot(Hit.ImpactPoint, Hit.ImpactNormal)
    else
        self.Visual:HideDot()
    end
end

return Laser
