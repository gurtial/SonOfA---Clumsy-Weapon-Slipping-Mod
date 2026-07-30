# Son of a! — Clumsy Weapon Slipping Mod

A Skyrim Special Edition gameplay mod. Swinging a weapon has a chance to make it
**slip out of your hands** and get flung forward — unpredictable, occasionally
humiliating combat that quietly favours brawlers, because the more you swing steel
around, the more likely you are to end up empty-handed.

Everything is configurable from an in-game **MCM** menu (SkyUI). Player-only by
design — it doesn't care about skill level or weapon type. A swing is a swing.

> **Open source & free to redistribute.** The author claims no ownership — feel
> free to re-publish, fork, port, or build on it. See [LICENSE](LICENSE) (public domain / The Unlicense).

---

## Features

| Feature | Behaviour |
|---|---|
| **Slip on swing** | Every melee swing (left or right hand) rolls a configurable % chance to launch the equipped weapon forward. |
| **Forward throw** | The weapon flies along your facing direction with a slight upward arc, toward your target rather than at your feet. |
| **Wall / whiff slips** | A swing with **no enemy in front of you** (into a wall, or whiffing at empty air) uses a separate chance. No dependencies. |
| **Degradation** | A slip can **tier the weapon's temper down** toward untempered. Shares the same value as **Loot and Degradation SE**, so the two stay in sync. |
| **Notification** | Optional "Son of a! Your weapon slipped!" toast. |

---

## Requirements

**Required**
- **SKSE64** — provides the `WornObject` temper functions and animation-event hooks.
- **SkyUI** — for the MCM.
- **MCM Helper** — renders the settings menu from `config.json`.

**Optional (no hard dependency, no patch needed)**
- **Loot and Degradation SE** — built-in compatibility. The degradation feature shares its temper value, so a slip quietly wears your gear down and you repair it at a grindstone like any other LaDSe wear. Works fine without it too; the temper just isn't tracked/repaired by anything else.

The plugin masters only `Skyrim.esm`, is ESL-flagged (`.esp`, no load-order slot), and
references nothing external. Plays nicely with **Precision** and combat frameworks
like **BFCO / MCO**, but requires none of them.

---

## Installation

Grab the archive from the [Releases](../../releases) page and install it with a mod
manager — **Vortex** ("Install From File") or **MO2** — or just extract it into your
`Data` folder. Or build it yourself (see [BUILD.md](BUILD.md)). It's a plain data-root
archive, so there's nothing to configure at install time. The Papyrus `.psc` source
lives in this repo under `Source/` if you want it.

Then: load a save → **Mod Configuration → "Son of a!"** → tune to taste.

---

## MCM settings

| Setting | Default | Notes |
|---|---:|---|
| Mod Enabled | On | Master switch. |
| Slip Chance vs an Enemy | 15% | Chance to slip when you swing with an enemy in front of you. |
| Throw Force | 100 | Havok impulse strength (5–150). Bigger = flies harder/further. |
| Show "Son of a!" Message | On | Corner notification on a slip. |
| Enable Wall / Whiff Slips | On | Use a separate chance when no enemy is in front. |
| Slip Chance vs Wall / Whiff | 15% | Roll for a swing that hits no enemy (into a wall or empty air). |
| Enable Weapon Degradation | On | |
| Degrade Chance on Slip | 15% | Chance a slip also degrades the weapon. |
| Temper Loss per Degrade | 10% | Item-health points removed per degrade (~one tier). Never drops below untempered. |

---

## How the trickier bits work (honest notes — skip if you like)

**"Wall / whiff" detection.** Skyrim gives Papyrus no signal for "my weapon just
touched a wall" — that only exists via a collision mod's SKSE code. So instead of
depending on one, the mod checks, on each swing, whether there's a living actor
within reach and roughly in front of you. If there is, the swing counts as *at an
enemy* and uses the enemy chance; if not, you're swinging into a wall or thin air
and it uses the wall/whiff chance. The two are mutually exclusive, so one swing
only rolls once. It's a proxy, not literal wall collision — a wide-open practice
swing counts as a "whiff" too — but it needs nothing but the base game.

**Degradation & Loot and Degradation SE.** Weapon temper in Skyrim is a single SKSE
value (item health percent). This mod lowers exactly that value — the same one LaDSe
reads and writes (`WornObject.SetItemHealthPercent`). So a degrade here is
indistinguishable from normal LaDSe wear. `1.0` (100%) is untempered and is the
floor — degrading never makes a weapon *worse* than un-smithed.

**Which weapon gets thrown.** It's dropped via the standard `DropObject`, which
carries its temper/enchantment along — pick it back up and it's unchanged (aside
from any degrade that rolled). If you carry several identical base weapons, the
engine picks which copy leaves your hand; for the usual "one of each" inventory
this is a non-issue.

**Throw feel.** `Throw Force` is a raw Havok impulse magnitude, so the ideal value
depends a little on your setup. ~100 is a proper throw; crank it up for full comedy,
down for a limp "whoops".

---

## How it's built (for tinkerers)

- Plugin: `SonOfAClumsyWeapon.esp` (ESL-flagged, master: `Skyrim.esm`).
- Quest `_SoaClumsyQuest` (`xx000809`), start-game-enabled, carries three scripts:
  - `SonOfAClumsyWeapon` — empty `MCM_ConfigBase` subclass; registers the MCM.
  - `_SoaClumsyController` — the gameplay logic.
  - `_SoaClumsyPlayerAlias` — a forced player alias that re-arms the animation events on load.
- Settings are Global Variables `xx000800`–`xx000808`; the MCM binds to them by
  `sourceForm`, so there are no script properties to fill.
- Source lives in [`Source/Scripts`](Source/Scripts). See [BUILD.md](BUILD.md) to
  compile and repackage.

---

## License

Public domain — [The Unlicense](LICENSE). Do whatever you want with it. Attribution
is appreciated but not required. (Note: this covers the mod's original scripts,
records and config; Bethesda retains rights to the game and Creation Kit assets, as
with any Skyrim mod.)
