# Building from source

This repo ships the compiled plugin and scripts ready to use, so you only need this
if you want to change something.

## Repo layout

```
SonOfAClumsyWeapon.esp                 prebuilt ESL-flagged plugin
Scripts/*.pex                          compiled Papyrus (what the game runs)
Source/Scripts/*.psc                   Papyrus source
MCM/Config/SonOfAClumsyWeapon/config.json   MCM Helper menu definition
fomod/                                 FOMOD installer definition
tools/package_fomod.py                 builds the distributable FOMOD zip
```

## 1. Compiling the Papyrus scripts

You need the **Creation Kit's Papyrus compiler** and the source scripts from
**SKSE**, **SkyUI** (the `SDK` folder), and — for `SonOfAClumsyWeapon.psc` only —
**MCM Helper's** `MCM_ConfigBase`.

Import-path order matters: the **SKSE-patched** base scripts (`Data\Scripts\Source`)
must come *before* the vanilla ones (`Data\Source\Scripts`), or functions like
`RegisterForModEvent` won't resolve.

```
PapyrusCompiler.exe "Source\Scripts\_SoaClumsyController.psc" ^
  -f=TESV_Papyrus_Flags.flg ^
  -i="Source\Scripts;<SkyUI SDK>;<Skyrim>\Data\Scripts\Source;<Skyrim>\Data\Source\Scripts" ^
  -o="Scripts"
```

Repeat for `_SoaClumsyPlayerAlias.psc` and `SonOfAClumsyWeapon.psc`.

`SonOfAClumsyWeapon.psc` is an **empty** `MCM_ConfigBase` subclass — its only job is
to register the MCM (MCM Helper matches the script name to the config folder). MCM
Helper ships `MCM_ConfigBase` only as a compiled `.pex` inside `MCMHelper.bsa`, so to
compile against it either extract that source or drop a one-line stub on your import
path:

```papyrus
Scriptname MCM_ConfigBase extends SKI_ConfigBase
```

Because the subclass is empty it references nothing from the parent, so the stub
produces byte-identical output to the real source. **Do not ship a compiled
`MCM_ConfigBase.pex`** — the real one comes from MCM Helper at runtime.

## 2. The plugin (`SonOfAClumsyWeapon.esp`)

Prebuilt and committed. It's a tiny ESL-flagged plugin: one start-game-enabled quest
(`_SoaClumsyQuest`, `xx000809`) carrying the three scripts, plus nine float
GlobalVariables (`xx000800`–`xx000808`) that back the MCM sliders/toggles. Edit it in
the **Creation Kit** or **xEdit** if you need to change records; nothing here depends
on regenerating it.

## 3. Packaging the FOMOD installer

```
python tools/package_fomod.py
```

Produces `dist/SonOfAClumsyWeapon-<version>.zip` (version read from `fomod/info.xml`),
laid out as `00 Core` (required) + `01 Source` (optional) + `fomod/`. Upload that zip
to the Releases page / Nexus.
