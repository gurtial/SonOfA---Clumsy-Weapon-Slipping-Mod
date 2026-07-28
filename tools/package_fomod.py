#!/usr/bin/env python3
"""
Build the distributable FOMOD installer for Son of a! - Clumsy Weapon Slipping.

Assembles the repo's loose files into the FOMOD layout that
fomod/ModuleConfig.xml expects (00 Core / 01 Source / fomod) and zips it.

Usage:
    python tools/package_fomod.py

Output:
    dist/SonOfAClumsyWeapon-<version>.zip   (version read from fomod/info.xml)

No third-party dependencies; standard library only.
"""
import os
import re
import shutil
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)                       # repo root = parent of tools/
DIST = os.path.join(REPO, "dist")
BUILD = os.path.join(DIST, "_build")

# (source path relative to repo, destination path inside the archive)
CORE = [
    ("SonOfAClumsyWeapon.esp",                              "00 Core/SonOfAClumsyWeapon.esp"),
    ("Scripts/_SoaClumsyController.pex",                    "00 Core/Scripts/_SoaClumsyController.pex"),
    ("Scripts/_SoaClumsyPlayerAlias.pex",                   "00 Core/Scripts/_SoaClumsyPlayerAlias.pex"),
    ("Scripts/SonOfAClumsyWeapon.pex",                      "00 Core/Scripts/SonOfAClumsyWeapon.pex"),
    ("MCM/Config/SonOfAClumsyWeapon/config.json",           "00 Core/MCM/Config/SonOfAClumsyWeapon/config.json"),
]
SOURCE = [
    ("Source/Scripts/_SoaClumsyController.psc",             "01 Source/Source/Scripts/_SoaClumsyController.psc"),
    ("Source/Scripts/_SoaClumsyPlayerAlias.psc",            "01 Source/Source/Scripts/_SoaClumsyPlayerAlias.psc"),
    ("Source/Scripts/SonOfAClumsyWeapon.psc",              "01 Source/Source/Scripts/SonOfAClumsyWeapon.psc"),
]
FOMOD = [
    ("fomod/info.xml",          "fomod/info.xml"),
    ("fomod/ModuleConfig.xml",  "fomod/ModuleConfig.xml"),
    ("README.md",               "README.md"),
]


def read_version():
    info = os.path.join(REPO, "fomod", "info.xml")
    text = open(info, encoding="utf-8").read()
    m = re.search(r"<Version>\s*(.*?)\s*</Version>", text)
    return m.group(1) if m else "1.0.0"


def stage(pairs):
    for src_rel, dst_rel in pairs:
        src = os.path.join(REPO, src_rel)
        if not os.path.isfile(src):
            raise SystemExit("missing file: %s" % src_rel)
        dst = os.path.join(BUILD, dst_rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)


def main():
    if os.path.isdir(BUILD):
        shutil.rmtree(BUILD)
    os.makedirs(BUILD)

    stage(CORE)
    stage(SOURCE)
    stage(FOMOD)

    version = read_version()
    out = os.path.join(DIST, "SonOfAClumsyWeapon-%s.zip" % version)
    if os.path.exists(out):
        os.remove(out)

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _dirs, files in os.walk(BUILD):
            for f in files:
                full = os.path.join(root, f)
                arc = os.path.relpath(full, BUILD).replace(os.sep, "/")  # zip = forward slashes
                z.write(full, arc)

    shutil.rmtree(BUILD)
    print("Built %s (%d bytes)" % (out, os.path.getsize(out)))


if __name__ == "__main__":
    main()
