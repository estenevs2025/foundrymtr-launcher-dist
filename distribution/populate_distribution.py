#!/usr/bin/env python3
"""
populate_distribution.py

Reads distribution.json, looks for each mod file in ./mods/, computes its MD5
and file size, and writes a new distribution-final.json with the values filled in.

This is the STAGING tool. The preferred production path is Nebula generation
(see docs/HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md section 3); this script is the
fallback hashing/sizing filler for the hand-maintained staging manifest.

Usage:
    1. Put all your mod .jar files in a folder called `mods/` next to this script.
    2. Run: python3 populate_distribution.py
    3. Validate per HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md section 7, then upload
       (binaries FIRST, manifest LAST).

Expected mod filenames in ./mods/ folder (the canonical 7-mod 1.21.4 set):
    mtr-nextgen-fabric-mc1.21.4-mtr4.1.0-beta.1-ng.dev1.jar
    fabric-api-0.119.4+1.21.4.jar
    sodium-fabric-0.6.13+mc1.21.4.jar
    lithium-fabric-0.15.3+mc1.21.4.jar
    ferritecore-7.1.3-fabric.jar
    Debugify-1.21.4+1.1.jar
    modmenu-13.0.4.jar
"""

import hashlib
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
DIST_IN = SCRIPT_DIR / "distribution.json"
DIST_OUT = SCRIPT_DIR / "distribution-final.json"
MODS_DIR = SCRIPT_DIR / "mods"


def md5_of(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def filename_from_url(url: str) -> str:
    return url.rsplit("/", 1)[-1]


def main() -> int:
    if not DIST_IN.exists():
        print(f"ERROR: {DIST_IN} not found.")
        return 1
    if not MODS_DIR.exists():
        print(f"ERROR: {MODS_DIR} folder not found. Create it and drop your jars in.")
        return 1

    with DIST_IN.open() as f:
        data = json.load(f)

    missing = []
    populated = 0

    for server in data.get("servers", []):
        for module in server.get("modules", []):
            artifact = module.get("artifact", {})
            url = artifact.get("url", "")
            mod_type = module.get("type", "")

            # Skip the Fabric loader module - that's a JSON descriptor, not a jar.
            if mod_type == "Fabric":
                continue

            fname = filename_from_url(url)
            local = MODS_DIR / fname

            if not local.exists():
                missing.append(fname)
                continue

            artifact["MD5"] = md5_of(local)
            artifact["size"] = local.stat().st_size
            populated += 1
            print(f"  OK  {fname}  ({artifact['size']:,} bytes)")

    if missing:
        print()
        print("MISSING FILES in ./mods/ folder:")
        for m in missing:
            print(f"  - {m}")
        print()
        print("Put these files in ./mods/ and re-run.")
        return 2

    with DIST_OUT.open("w") as f:
        json.dump(data, f, indent=2)

    print()
    print(f"SUCCESS: {populated} modules populated. Wrote {DIST_OUT}")
    print()
    print("Next steps (order matters - binaries first, manifest LAST):")
    print("  1. Upload all jars in mods/ to: https://files.foundrymtr.com/servers/foundrymtr/mods/")
    print("  2. Verify hash + size against R2 (HELIOS_CLOUDFLARE_INTEGRATION_PLAN.md section 7).")
    print(f"  3. Rename {DIST_OUT.name} to distribution.json and upload to:")
    print("     https://files.foundrymtr.com/helios/distribution.json (then purge that URL)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
