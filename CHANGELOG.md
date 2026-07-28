# Changelog

## 1.0.0
- Initial release.
- Melee swings (left/right hand) roll a chance to fling the equipped weapon forward.
- Separate, mutually-exclusive slip chances for swinging **at an enemy** vs **into a wall / thin air**.
- Optional weapon **degradation** that tiers temper down toward untempered — compatible with Loot and Degradation SE (shared SKSE item-health value).
- Fully configurable in-game via MCM (MCM Helper): master toggle, both slip chances, throw force, notification, and all degradation options.
- ESL-flagged, masters only `Skyrim.esm`, no hard dependencies beyond SKSE64 / SkyUI / MCM Helper.
