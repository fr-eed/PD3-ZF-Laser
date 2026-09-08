-- UE4SS glue shared by every module
local Vec = require("core.vec")

local Game = {}

function Game.Log(fmt, ...)
    print(string.format("[ZF-Laser] " .. fmt .. "\n", ...))
end

-- Keybinds and notifications run off the game thread
function Game.OnGameThread(Body)
    ExecuteInGameThread(function()
        local Ok, Err = pcall(Body)
        if not Ok then Game.Log("error: %s", tostring(Err)) end
    end)
end

-- Loads by package and object name through the asset registry. Taken from
-- UE4SS's bundled BPModLoaderMod, which loads Blueprint mods this way:
-- https://github.com/UE4SS-RE/RE-UE4SS/blob/main/assets/Mods/BPModLoaderMod/Scripts/main.lua
-- UE4SS's own LoadAsset is currently unreliable in this game.
function Game.LoadByPath(PackageName, AssetName)
    local Helpers = StaticFindObject("/Script/AssetRegistry.Default__AssetRegistryHelpers")
    local Ok, Object = pcall(function()
        return Helpers:GetAsset({ PackageName = FName(PackageName), AssetName = FName(AssetName) })
    end)
    if Ok and Object and Object:IsValid() then return Object end
    local Found = StaticFindObject(PackageName .. "." .. AssetName)
    if Found and Found:IsValid() then return Found end
    return nil
end

-- Class default objects, looked up once.
local Defaults = {}
function Game.Default(Path)
    local Object = Defaults[Path]
    if Object and Object:IsValid() then return Object end
    Object = StaticFindObject(Path)
    Defaults[Path] = Object
    return Object
end

-- The actor an animation instance animates, or nil. Nothing is looked up
-- or cached: after a heist restart the old controller and character stay
-- in the object list for a while, and any search would find them first.
function Game.OwnerOf(AnimInstance)
    if not AnimInstance or not AnimInstance:IsValid() then return nil end
    local Owner = AnimInstance:GetOwningActor()
    if Owner and Owner:IsValid() then return Owner end
    return nil
end

function Game.Camera(Pawn)
    local Owner = Pawn.Controller
    local Camera = Owner and Owner:IsValid() and Owner.PlayerCameraManager
    if Camera and Camera:IsValid() then return Camera end
    return nil
end

function Game.SocketName(Weapon)
    return FName(Weapon.FireEffectSocket:ToString())
end

-- The muzzle socket as a frame: origin and axes in the world.
function Game.MuzzleFrame(Weapon, Socket)
    return Vec.Frame(Weapon.Mesh:GetSocketLocation(Socket), Weapon.Mesh:GetSocketRotation(Socket))
end

function Game.DeltaSeconds(Context)
    return Game.Default("/Script/Engine.Default__GameplayStatics"):GetWorldDeltaSeconds(Context)
end

-- UE4SS never frees a table it fills as an out parameter, so a new table per
-- call is a memory leak. So one table is reused, cleared before each call,
-- else UE4SS logs a warning per weak pointer.
function Game.Reuse(Table)
    for Key in pairs(Table) do Table[Key] = nil end
    return Table
end

local Attached = {}
local WorldHit, PawnHit = {}, {}

-- The ignore list for traces: the weapon and every actor attached to it,
-- which is where the game's attachments and charms hang, so the beam does collide on its own gun.
function Game.WeaponActors(Weapon)
    local List = { Weapon }
    pcall(function()
        Weapon:GetAttachedActors(Game.Reuse(Attached), true, true)
        for _, Actor in ipairs(Attached) do
            if type(Actor.get) == "function" then Actor = Actor:get() end
            if Actor and Actor:IsValid() then List[#List + 1] = Actor end
        end
    end)
    return List
end

local Red, Green = { R = 1.0, G = 0.0, B = 0.0, A = 1.0 }, { R = 0.0, G = 1.0, B = 0.0, A = 1.0 }
local Visibility = 0   -- ETraceTypeQuery::TraceTypeQuery1
local Pawns = { 2 }    -- EObjectTypeQuery::Pawn

-- Line trace on the visibility channel. Returns the hit table or nil.
-- The table is the same one every call, valid until the next TraceWorld.
function Game.TraceWorld(Context, Start, End, Ignore)
    local Hit = Game.Reuse(WorldHit)
    local Library = Game.Default("/Script/Engine.Default__KismetSystemLibrary")
    if Library:LineTraceSingle(Context, Start, End, Visibility, false, Ignore, 0, Hit, true, Red, Green, 0.0) then
        return Hit
    end
    return nil
end

-- Characters don't block the visibility channel, so they are traced by object type.
-- Returns the hit table or nil, valid until the next TracePawns.
function Game.TracePawns(Context, Start, End, Ignore)
    local Hit = Game.Reuse(PawnHit)
    local Library = Game.Default("/Script/Engine.Default__KismetSystemLibrary")
    if Library:LineTraceSingleForObjects(Context, Start, End, Pawns, false, Ignore, 0, Hit, true, Red, Green, 0.0) then
        return Hit
    end
    return nil
end

return Game
