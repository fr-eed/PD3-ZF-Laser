-- ZF-Laser: a laser sight for PAYDAY 3. Adds a beam and a dot to the gun in
-- hand, using the game's own materials.
--
--   - Follows the gun through sway, reloads and weapon swaps.
--     Turns off during a gadget, melee or interaction 'in hands'.
--   - Zeroes itself to the crosshair, because the gun models don't point
--     where the game shoots and differ per weapon and stance (core/zeroing.lua).
--   - Dot on whatever the beam hits, people included, through glass.
--   - Drawn in the same render pass as the gun, so it lines up at any FOV.
--   - Per-weapon overrides for the odd ones, like the M135 Arges.
--   - Settings section in Settings > Interface. key 0 by default toggles laser.
--   - Click sound on laser on/off. Reused from the game's cutting tool.
--
local Config = require("config")
local Game = require("engine.game")
local Laser = require("laser.laser")
local Sound = require("engine.sound")
local Menu = require("ui.menu")
local Version = require("version")

Config.Load()

local Equipped = 2   -- ESBZEquipState
local FramePath = "/Game/Gameplay/Player/ABP_FPPlayerBase.ABP_FPPlayerBase_C:BlueprintUpdateAnimation"

local Lasers = {}         -- weapon address -> Laser
local FrameHooked = false
local Creating = nil      -- weapon address whose laser is being spawned

-- Cleared in place: dev.lua keeps a reference to this table.
local function DestroyAll()
    for Address, Item in pairs(Lasers) do
        Item:Destroy()
        Lasers[Address] = nil
    end
end

-- Zip-ties, drill repairs and the like keep the gun equipped but move it out of the view.
-- Lockpicking and hacking are minigames rather than interactions; the
-- character holds the running one.
local function Interacting(Player)
    local Ok, Busy = pcall(function()
        local Interaction = Player.Interactor.CurrentInteraction
        if Interaction and Interaction:IsValid() then return true end
        local MiniGame = Player.CurrentMiniGameComponent
        return MiniGame and MiniGame:IsValid()
    end)
    return Ok and Busy
end

-- A ranged weapon the config hasn't excluded.
local function WantsLaser(Equippable)
    local Ranged = Game.Default("/Script/Starbreeze.SBZRangedWeapon")
    if not Equippable:IsA(Ranged) then return false end
    return Laser.TuningFor(Config, Equippable:GetClass():GetFName():ToString()).Enabled
end

-- Loading assets and spawning actors inside the animation update freezes the game,
-- so creation is queued for a safe point.
local function CreateLater(Weapon)
    local Address = Weapon:GetAddress()
    if Creating == Address then return end
    Creating = Address
    Game.OnGameThread(function()
        if Weapon:IsValid() and not Lasers[Address] then
            Lasers[Address] = Laser.New(Weapon, Config)
        end
        Creating = nil
    end)
end

local function OnFrame()
    local Ok, Err = pcall(function()
        local Player = Game.Pawn()
        if not Player then return end
        for Address, Item in pairs(Lasers) do
            if not Item:IsValid() then
                Item:Destroy()
                Lasers[Address] = nil
            end
        end

        local Current = Player.CurrentEquippable
        local InHand = Player.EquipState == Equipped and Current and Current:IsValid()

        local Wanted = (Config.Enabled and InHand and not Interacting(Player) and WantsLaser(Current)) and Current or nil
        for _, Item in pairs(Lasers) do
            if not Wanted or Item.Weapon:GetAddress() ~= Wanted:GetAddress() then
                if Item.On then Sound.Play(Config, Item.Weapon) end
                Item:SetOn(false)
            end
        end
        if not Wanted then return end

        local Item = Lasers[Wanted:GetAddress()]
        if not Item then return CreateLater(Wanted) end
        if not Item.On then
            Item:SetOn(true)
            Sound.Play(Config, Wanted)
        end
        Item:Update(Player, Game.Camera())
    end)
    if not Ok then Game.Log("frame error: %s", tostring(Err)) end
end

-- The arms animation Blueprint is the only per-frame Blueprint in play, and only Blueprints can be hooked.
-- It exists once a heist has loaded, so the hook is attempted whenever a player character appears.
local function HookFrame()
    if FrameHooked then return end
    local Found = StaticFindObject(FramePath)
    if not Found or not Found:IsValid() then return end
    local Ok, Err = pcall(RegisterHook, FramePath, OnFrame)
    FrameHooked = Ok
    Game.Log("per-frame hook %s", Ok and "installed" or ("failed: " .. tostring(Err)))
end

-- A new player character means a new heist
-- The callback fires while the character is still being constructed, and destroying actors or
-- registering hooks at that moment can crash, so the work is queued for the game thread's next safe point.
NotifyOnNewObject("/Script/Starbreeze.SBZPlayerCharacter", function()
    Game.OnGameThread(function()
        Game.ForgetPawn()
        DestroyAll()
        HookFrame()
    end)
end)

RegisterKeyBind(Key[Config.Key], {}, function()
    Game.OnGameThread(function()
        Config.Enabled = not Config.Enabled
        Config.Save()
        HookFrame()
        Game.Log("laser %s", Config.Enabled and "on" or "off")
    end)
end)

-- After any change from the menu the lasers are rebuilt, so size, mount and brightness changes show at once.
Menu.Install(Config, DestroyAll)

-- Development aids live in dev.lua
local HasDev, Dev = pcall(require, "dev")
if HasDev then Dev.Install(Laser, Lasers) end

Game.Log("v%s loaded; laser %s, key %s toggles, sound %s",
    Version, Config.Enabled and "on" or "off", Config.Key, Config.Sound.Enabled and "on" or "off")
