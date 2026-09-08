# ZF-Laser

A laser sight for PAYDAY 3. A beam and a dot on the gun in hand

- Follows the gun through sway, reloads and weapon swaps.
- Zeros itself automatically to the crosshair. Game's viewmodels don't point where the gun shoots.
- Dot on the first thing the beam collision.
- Per-weapon overrides for the odd ones, like the M135 Arges.
- Settings section in Settings > Interface. Key 0 toggles the laser by default. Choices are saved.
- Click sound on switch, and a color picker.

Download from the [GitHub releases](https://github.com/fr-eed/PD3-ZF-Laser/releases).
Also listed on [ModWorkshop](https://modworkshop.net/mod/58787).

## Install

Requires the PAYDAY 3 UE4SS loader: [PD3 UE4SS V3.01 + Allow Pak Mods](https://modworkshop.net/mod/47771) on ModWorkshop.

Copy `Mods/ZF-Laser` into the loader's `Mods` folder so you have `Mods/ZF-Laser/enabled.txt` and `Mods/ZF-Laser/Scripts/`.

## Settings

In game: Settings > Interface, scroll to the ZF-LASER section.
Afterwards user settings is saved in `Scripts/settings.lua`.

## Extra configuration

`Scripts/config.lua` defines the defaults and a few values that have no menu row.
Edit it with the game closed.

`settings.lua` is written by the menu and overrides the matching values in
`config.lua`. Don't edit it by hand; it's rewritten on every menu change.

| Value | Meaning |
|---|---|
| `Key` | The toggle key, a UE4SS key name. Default `ZERO` (0). |
| `Segment.Length`, `Segment.Count` | Beam reach is length times count, in meters. |
| `Segment.Thickness` | Beam diameter in meters. |
| `Dot.Lift` | How far the dot floats off the surface, in cm. |
| `Zeroing.MaxAngle` | How far an aim line can deviate from the bore for the `Zeroing.ToAim` to track, in degrees. |
| `Zeroing.Time` | How long the correction averages over, in seconds. Higher lets more sway through. Set to 0 for instant targeting |
| `Sound.Package`, `Sound.Event` | The Wwise event for the click, as its package path and event name. |
| `Weapons` | Per-weapon overrides, keyed by the weapon's class name. |

A `Weapons` entry may contain any of `Enabled`, `Mount`, `Zeroing` and `Bore`

Whatever it leaves out falls back to the global value.
`Bore` is a fixed pitch and yaw in degrees added to the barrel direction,
for guns whose viewmodel points nowhere near where they shoot:

Example:
```lua
["BP_RangedWeapon_OVK_ARGES_C"] = {
    Zeroing = { MaxAngle = 20.0 },
    Bore = { Pitch = -8.5, Yaw = 0.1 },
},
```

## Adding a weapon override

1. Draw the weapon. The log prints `laser on <class name>`.
2. Stand still and aim at a wall.
3. Press 6 (needs `dev.lua`). The log prints the pitch and yaw the beam is off by.
4. Add an entry for that class name under `Weapons` in `config.lua` with those two values as `Bore`.

## Layout

```
Scripts/
  main.lua        lifecycle and keys
  config.lua      defaults, load, save, reset
  dev.lua         optional: key 6 logs a weapon's bore offset
  core/           math: vectors, color, zeroing, tuning
  engine/         UE4SS glue: game objects, traces, sound
  laser/          visual.lua draws a laser, laser.lua aims
  ui/             the settings hooks and rows
```
