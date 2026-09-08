-- The visible laser: beam segments attached to the muzzle socket and a dot placed at the collision
local Vec = require("core.vec")
local Color = require("core.color")
local Game = require("engine.game")

-- The material comes from the game's laser-grid trap.
-- The beam is the engine's cylinder and the dot its sphere.
-- A map change can garbage-collect loaded assets, so they are checked before every use.
local Assets = {}   -- the meshes and material, revalidated after map changes
local Loaded = nil

local function Valid()
    if not Loaded then return false end
    for _, Object in pairs(Loaded) do
        if not Object or not Object:IsValid() then return false end
    end
    return true
end

-- Returns { BeamMesh, DotMesh, Material, ActorClass, Math } or nil.
function Assets.Get()
    if Valid() then return Loaded end
    Loaded = nil
    local Class = Game.LoadByPath("/Game/Gameplay/Laser/BP_Laser", "BP_Laser_C")
    if not Class then Game.Log("could not load BP_Laser_C") return nil end
    local Defaults = Class:GetCDO()
    Loaded = {
        Material = Defaults:GetMaterial(0),
        BeamMesh = Game.LoadByPath("/Engine/BasicShapes/Cylinder", "Cylinder") or Defaults.StaticMesh,
        DotMesh = Game.LoadByPath("/Engine/BasicShapes/Sphere", "Sphere") or Defaults.StaticMesh,
        ActorClass = StaticFindObject("/Script/Engine.StaticMeshActor"),
        Math = StaticFindObject("/Script/Engine.Default__KismetMathLibrary"),
    }
    if not Valid() then
        Game.Log("beam assets incomplete")
        Loaded = nil
    end
    return Loaded
end


local Visual = {}
Visual.__index = Visual

local Movable = 2      -- EComponentMobility
local SnapToTarget = 2 -- EAttachmentRule
local KeepWorld = 1    -- EAttachmentRule, for scale
local Sweep = {}       -- the sweep result every move writes, see Game.Reuse

-- A movable, collision-free mesh actor with the beam material in the given color.
-- Starbreeze's engine draws first-person meshes in a "top pass" with
-- the gun's own field of view. The beam is drawn in whichever pass the gun is in,
-- else it sways off the muzzle whenever the player FOV and gun FOV differ.
-- The flag is read when the render state is built, so it is set before the mesh.
local function SpawnGlow(World, Loaded, Mesh, At, Rot, Tint, TopPass)
    local Actor = World:SpawnActor(Loaded.ActorClass, At, Rot)
    if not Actor or not Actor:IsValid() then return nil end
    Actor:SetMobility(Movable)
    Actor:SetActorEnableCollision(false)
    local Comp = Actor.StaticMeshComponent
    Comp.bRenderInTopPass = TopPass
    if Mesh and Mesh:IsValid() then Comp:SetStaticMesh(Mesh) end
    if Loaded.Material and Loaded.Material:IsValid() then Comp:SetMaterial(0, Loaded.Material) end
    local Dynamic = Comp:CreateDynamicMaterialInstance(0, nil, FName("None"))
    if Dynamic and Dynamic:IsValid() then Dynamic:SetVectorParameterValue(FName("Color"), Tint) end
    Actor:SetActorHiddenInGame(true)
    return Actor
end

-- Spawns the segments attached at the muzzle socket, and the dot, all
-- hidden. Mount is the emitter offset the lay-out uses. Returns nil if
-- anything failed.
function Visual.New(Weapon, Socket, Config, Mount)
    local Loaded = Assets.Get()
    if not Loaded then return nil end
    local World = Weapon:GetWorld()
    local At = Weapon.Mesh:GetSocketLocation(Socket)
    local Rot = Weapon.Mesh:GetSocketRotation(Socket)
    local Segment = Config.Segment
    local Self = setmetatable({
        Segments = {}, Segment = Segment, Mount = Mount, Math = Loaded.Math,
        TopPass = Visual.GunPass(Weapon),
    }, Visual)

    -- The cylinder's long axis is Z.
    local Scale = { X = Segment.Thickness, Y = Segment.Thickness, Z = Segment.Length }
    local BeamColor = Color.Material(Config.Hue, Config.Brightness)
    for Index = 1, Segment.Count do
        local Actor = SpawnGlow(World, Loaded, Loaded.BeamMesh, At, Rot, BeamColor, Self.TopPass)
        if not Actor then Self:Destroy() return nil end
        Actor:K2_AttachToComponent(Weapon.Mesh, Socket, SnapToTarget, SnapToTarget, KeepWorld, false)
        Actor:SetActorScale3D(Scale)
        Self.Segments[Index] = Actor
    end

    local DotColor = Color.Material(Config.Hue, Config.Dot.Brightness)
    Self.Dot = SpawnGlow(World, Loaded, Loaded.DotMesh, At, Rot, DotColor, Self.TopPass)
    if not Self.Dot then Self:Destroy() return nil end
    Self.Dot:SetActorScale3D({ X = Config.Dot.Size, Y = Config.Dot.Size, Z = Config.Dot.Size })
    Self.Lift = Config.Dot.Lift
    return Self
end

-- Whether the gun's mesh is drawn in the top pass right now.
function Visual.GunPass(Weapon)
    local Ok, Marked = pcall(function() return Weapon.Mesh.bRenderInTopPass end)
    return Ok and Marked == true
end

-- Moves every mesh to the given pass. The flag is only read when the render
-- state is built, and toggling custom depth makes the engine rebuild it.
function Visual:SetPass(TopPass)
    if self.TopPass == TopPass then return end
    self.TopPass = TopPass
    for _, Actor in ipairs({ self.Dot, table.unpack(self.Segments) }) do
        if Actor and Actor:IsValid() then
            local Comp = Actor.StaticMeshComponent
            Comp.bRenderInTopPass = TopPass
            local Depth = Comp.bRenderCustomDepth
            Comp:SetRenderCustomDepth(not Depth)
            Comp:SetRenderCustomDepth(Depth)
        end
    end
end

function Visual:IsValid()
    return self.Segments[1] ~= nil and self.Segments[1]:IsValid()
end

-- Segments end to end from the emitter along Aim, a unit direction in thw socket's frame.
function Visual:LayOut(Aim)
    local Segment, Mount = self.Segment, self.Mount
    -- The cylinder is first pitched so its Z axis lies along X, then aimed.
    local Rot = self.Math:ComposeRotators({ Pitch = -90.0, Yaw = 0.0, Roll = 0.0 }, Vec.ToRotator(Aim))
    for Index, Actor in ipairs(self.Segments) do
        if Actor:IsValid() then
            local Distance = (Index - 0.5) * Segment.Length * 100.0
            Actor:K2_SetActorRelativeRotation(Rot, false, Game.Reuse(Sweep), false)
            Actor:K2_SetActorRelativeLocation({
                X = Mount.Forward + Aim.X * Distance,
                Y = Mount.Right + Aim.Y * Distance,
                Z = Mount.Up + Aim.Z * Distance,
            }, false, Game.Reuse(Sweep), false)
        end
    end
end

-- Shows or hides the segments. The dot is placed or hidden separately.
function Visual:SetOn(On)
    for _, Actor in ipairs(self.Segments) do
        if Actor:IsValid() then Actor:SetActorHiddenInGame(not On) end
    end
    if not On then self:HideDot() end
end

-- The dot on a surface, lifted along its normal and facing it.
function Visual:PlaceDot(Point, Normal)
    if not self.Dot:IsValid() then return end
    self.Dot:K2_SetActorLocationAndRotation(Vec.Add(Point, Vec.Scale(Normal, self.Lift)), Vec.ToRotator(Normal), false, Game.Reuse(Sweep), false)
    self.Dot:SetActorHiddenInGame(false)
end

function Visual:HideDot()
    if self.Dot and self.Dot:IsValid() then self.Dot:SetActorHiddenInGame(true) end
end

function Visual:Destroy()
    for _, Actor in ipairs(self.Segments) do
        if Actor:IsValid() then Actor:K2_DestroyActor() end
    end
    if self.Dot and self.Dot:IsValid() then self.Dot:K2_DestroyActor() end
    self.Segments = {}
end

return Visual
