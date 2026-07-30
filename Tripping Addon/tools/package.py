r"""
Package this Skyrim SE mod folder into a clean, data-root release zip.

The archive root maps 1:1 onto the game's Data\ folder and contains ONLY the
runtime payload:
    <plugin>.esp/.esm/.esl (+ any .bsa), Scripts\**\*.pex, MCM\**

It deliberately EXCLUDES source (.psc), docs (README/LICENSE/CHANGELOG), tooling,
and previous build output. Generic-named files like README.md/LICENSE must never
ship inside a mod's Data payload -- they collide with every other mod that ships
one (that is the "unresolved file conflicts" Vortex reports). Docs belong in the
repo and the Nexus description.

Install: Vortex "Install From File", MO2, or just extract into Data\. No FOMOD.

Usage:  py -3 tools/package.py [version]      (version defaults to 1.0)
"""
import os, glob, zipfile, sys

ROOT    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSION = sys.argv[1] if len(sys.argv) > 1 else "1.0"

def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")

# --- discover the runtime payload -------------------------------------------
payload, plugins = [], []
for pat in ("*.esp", "*.esm", "*.esl", "*.bsa"):
    for p in glob.glob(os.path.join(ROOT, pat)):
        payload.append(p)
        if not p.lower().endswith(".bsa"):
            plugins.append(p)
payload += glob.glob(os.path.join(ROOT, "Scripts", "**", "*.pex"), recursive=True)
payload += [p for p in glob.glob(os.path.join(ROOT, "MCM", "**", "*"), recursive=True)
            if os.path.isfile(p)]

if not plugins:
    print("ERROR: no .esp/.esm/.esl found in", ROOT); sys.exit(1)

# --- safety guard: nothing non-data may slip into a Data payload -------------
GENERIC = {"readme.md", "readme.txt", "license", "license.txt",
           "changelog.md", "changelog.txt", "credits.txt"}
for p in payload:
    base = os.path.basename(p).lower()
    if base in GENERIC or base.endswith(".psc"):
        print("ERROR: non-data file in payload:", rel(p)); sys.exit(1)

# --- write, naming the archive after the plugin ------------------------------
mod = os.path.splitext(os.path.basename(sorted(plugins)[0]))[0]
out = os.path.join(ROOT, "dist", f"{mod}-{VERSION}.zip")
os.makedirs(os.path.dirname(out), exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(set(payload)):
        z.write(p, rel(p))          # arcname == path from mod root == Data\ layout
print(f"wrote {rel(out)}  (data-root, no FOMOD, no docs)")
with zipfile.ZipFile(out) as z:
    for n in z.namelist():
        print("   ", n)
