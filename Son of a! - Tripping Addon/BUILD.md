# Building — Son of a! — Tripping

## Compiling the scripts

Three scripts live in `Source/Scripts/`:

- `_SoaTripController.psc` — the logic (Quest script).
- `_SoaTripPlayerAlias.psc` — the player alias that catches drops.
- `SonOfATripping.psc` — the empty MCM registrar (`extends MCM_ConfigBase`).

The controller and alias compile against the normal SKSE + base-game sources.
The registrar needs `MCM_ConfigBase`, which ships only as a `.pex` inside
`MCMHelper.bsa`. Because the registrar is **empty**, you can compile it against a
one-line stub chain and the output is byte-identical to a "real" build:

```
Scriptname SKI_ConfigBase extends Quest
Scriptname MCM_ConfigBase extends SKI_ConfigBase
```

Compile (adjust paths to your install):

```bat
set GAME=C:\Program Files (x86)\Steam\steamapps\common\Skyrim Special Edition
set SRC=Source\Scripts
set STUB=<folder with the two stub .psc above>
set OUT=Scripts

"%GAME%\Papyrus Compiler\PapyrusCompiler.exe" "%SRC%\_SoaTripController.psc" -f="TESV_Papyrus_Flags.flg" -i="%SRC%;%STUB%;%GAME%\Data\Scripts\Source;%GAME%\Data\Source\Scripts" -o="%OUT%"
```

Repeat for the other two scripts. Import order matters: the SKSE-patched
`Data\Scripts\Source` must come **before** `Data\Source\Scripts`.

Ship only the three child `.pex` in `Scripts/` — never the stub `.pex`.

## The plugin

`SonOfATripping.esp` is ESL-flagged and masters only `Skyrim.esm`. It contains:

- 10 float Global Variables, `xx000800`–`xx000809` (the MCM settings).
- One start-game-enabled quest `_SoaTripQuest` (`xx00080A`) carrying the two
  quest scripts above and a forced `PlayerRef` alias (`ALFR = 0x14`) running
  `_SoaTripPlayerAlias`.

Rebuild it in the Creation Kit, or from the included byte-builder in
`tools/` history if you are cloning structures without the CK.

## Packaging

```
py -3 tools/package.py 1.0.0
```

produces `dist/SonOfATripping-1.0.0.zip` — a plain **data-root** archive (its root maps
1:1 onto `Data\`). It contains only the runtime payload (`.esp`, `Scripts\*.pex`,
`MCM\Config\SonOfATripping\`) — no docs, no source, no FOMOD. Installs via Vortex
"Install From File", MO2, or a manual extract into `Data\`, and never conflicts with
other mods over generic files like `README.md`. Docs and source stay in the repo /
Nexus description.
