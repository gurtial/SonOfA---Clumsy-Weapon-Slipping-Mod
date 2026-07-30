Son of a! — Tripping (addon)

An optional companion to **Son of a! — Clumsy Weapon Slipping**.

Walking over something you dropped on the ground now has a chance to make you **trip** — full ragdoll, straight into the dirt. It exists for one reason: it is genuinely funny that you can fumble your sword mid-fight and then, a second later, faceplant over the very sword you just dropped. That is the whole mod.

Everything is configurable from an in-game **MCM** menu (SkyUI). I claim no ownership of this mod — re-publish, fork, or butcher it however you like.

---

## What it actually does

- Every time **you** drop an item into the world, that item is quietly watched for a little while.
- While it is being watched, walking onto it rolls a chance to trip you.
- A trip is a ragdoll — you hit the ground, get up, carry on (probably to trip again).
- It pairs with **Clumsy Weapon Slipping** for free: a weapon that "slips" out of your hand is just an item you dropped, so it becomes trippable automatically. **No patch, no load-order rules, no dependency between the two.**

It works completely on its own, too — it will trip you over anything you drop by hand, Clumsy Weapon Slipping installed or not.

---

## Requirements

**Required**
- **SKSE64** — for the inventory + timing hooks.
- **SkyUI** — for the MCM.
- **MCM Helper** — renders the settings menu from `config.json` (no extra ESP needed for the menu).

**Recommended (not required)**
- **Son of a! — Clumsy Weapon Slipping** — the mod this is an addon for. Slipped weapons become trip hazards. Neither mod depends on the other; install either, both, or neither.

The plugin masters only `Skyrim.esm`, is ESL-flagged (`.esp`, takes no load-order slot), and references nothing external — so it loads fine anywhere.

---

## Settings (MCM)

| Setting | Default | What it does |
|---|---|---|
| Mod Enabled | On | Master switch. |
| Trip Chance | 25% | Chance to trip on a single walk over a dropped object. |
| Show "Son of a!" Message | On | Corner toast when you trip. |
| Only Dropped Weapons | On | On: only weapons you drop are hazards. Off: *anything* you drop is (potions, armour, cheese). |
| Trippable Window | 60 s | How long after dropping something it can still trip you. |
| Let NPCs Trip Too | **Off** | Experimental. Lets NPCs standing on your dropped items trip as well. |
| NPC Trip Chance | 15% | Separate, lower chance for NPCs. |
| Trip Radius | 75 | How close counts as "standing on it" (game units). |
| Ragdoll Force | 0 | 0 = flop where you stand. Higher = launched. Crank it for comedy. |
| Trip Cooldown | 3 s | Minimum gap between trips, so you can stand up first. |

> **Ragdoll Force tuning:** `0` gives a gentle collapse in place. If your setup makes that look too subtle, nudge it up to ~10–30 for a proper stumble-and-sprawl. It is a raw knockback magnitude, so the sweet spot depends a little on your other combat/physics mods — that is exactly why it is a slider.

---

## Honest notes (skippable)

**What can trip you.** Only things **you** put on the ground. There is no scan of world clutter, corpses, or other people's junk — Skyrim gives Papyrus no cheap, reliable "is there a physics object under my foot?" query without pulling in extra script-extender libraries, and I wanted this to need nothing but the same stack the base mod already uses. Watching your *own* drops is exact, cheap, and — conveniently — the only case that is actually funny.

**Why the "Trippable Window".** A dropped weapon can lie in the world forever. Rather than watch every item you have ever dropped for all eternity (death in a big modpack), each drop is only a hazard for a short window after it lands, and only while its cell is loaded. After that it is just a normal item on the floor. The addon watches at most a handful of recent drops and stops polling entirely once they age out — so it is quiet when you are not littering.

**NPCs (experimental, off by default).** When enabled, an NPC standing on one of *your* dropped items can trip too. It only ever considers actors already next to a watched object (no world-wide actor scan), skips anyone dead, sitting, mounted, swimming, mid-jump, or in a kill-move, and never damages anyone — it just knocks them down. It is off by default purely to stay polite in large modpacks; turn it on for chaos.

**It is a ragdoll, not a scripted animation.** Trips use the engine's knockback (`PushActorAway`) from the object under your feet, so you fall *away* from what you tripped over. No new animations, no FNIS/Nemesis, no compatibility patches.

---

## Uninstalling

Settings live in in-plugin Global Variables and the addon adds nothing to the world, so you can switch it off in the MCM and remove the plugin. As with any script mod a clean save is safest, but for something this small it is rarely necessary.

---

## For tinkerers

- Plugin: `SonOfATripping.esp` (ESL-flagged, master: `Skyrim.esm`).
- Quest `_SoaTripQuest` (`xx00080A`), start-game-enabled, holds the MCM registrar script, the controller script, and a forced player alias.
- `_SoaTripPlayerAlias` catches the player's `OnItemRemoved` (a real *drop* = a world reference with no destination container) and hands the reference to the controller.
- `_SoaTripController` keeps a small ring buffer of recent drops and polls footing with `RegisterForSingleUpdate` only while something is being watched.
- Settings are Global Variables `xx000800`–`xx000809`; the MCM binds to them by `sourceForm`, so there are no script properties to fill.
- Source is included under `Source\Scripts`. Compile against SKSE + SkyUI (+ an `MCM_ConfigBase`/`SKI_ConfigBase` stub for the empty registrar).
