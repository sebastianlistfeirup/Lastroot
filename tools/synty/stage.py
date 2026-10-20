#!/usr/bin/env python3
"""Copies only the chosen files from quarantine into assets/imported/ (gitignored).

For every slot in data/art/synty_choices.json with status auto/approved/manual and a
source, copies the model (plus a .gltf's .bin) and the pack's atlas textures to
assets/imported/<pack>/<same relative path>; also every chosen animation clip.
Nothing else from a pack enters the project. Writes assets/imported/<pack>/staged.json.

  python3 tools/synty/stage.py [--choices data/art/synty_choices.json]
Then: godot --headless --path . --import   (tools/synty/build.sh does all of it)
"""
import argparse, json, os, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
Q = os.path.join(ROOT, "assets", "quarantine")
IMPORTED = os.path.join(ROOT, "assets", "imported")
BUILD_STATUS = ("auto", "approved", "manual")
IMAGE_EXT = (".png", ".tga", ".jpg", ".jpeg", ".psd")


def atlas_files(pack):
    """Colour atlases: images named *Texture* (Synty convention) or in a Textures folder."""
    mpath = os.path.join(Q, pack, "manifest.json")
    if not os.path.exists(mpath):
        return []
    mf = json.load(open(mpath, encoding="utf-8"))
    imgs = [f["path"] for f in mf["files"] if f["path"].lower().endswith(IMAGE_EXT)]
    named = [p for p in imgs if "texture" in os.path.basename(p).lower()]
    return named or [p for p in imgs if "/textures/" in "/" + p.lower()]


def copy(pack, rel):
    src = os.path.join(Q, pack, rel)
    dst = os.path.join(IMPORTED, pack, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if not os.path.exists(dst) or os.path.getmtime(src) > os.path.getmtime(dst):
        shutil.copy2(src, dst)
    if rel.lower().endswith(".gltf"):
        b = os.path.splitext(rel)[0] + ".bin"
        if os.path.exists(os.path.join(Q, pack, b)):
            copy(pack, b)
    return os.path.relpath(dst, ROOT).replace(os.sep, "/")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--choices", default=os.path.join(ROOT, "data", "art", "synty_choices.json"))
    a = ap.parse_args()
    if not os.path.exists(a.choices):
        print("FEJL: %s findes ikke endnu. Kør først: python3 tools/synty/unpack.py <pakke> og python3 tools/synty/match.py. "
              "Intet er kopieret; spillet bruger stadig proxies." % os.path.relpath(a.choices, ROOT), file=sys.stderr)
        print("ERROR: %s not found. Run unpack.py and match.py first. Nothing was staged." % a.choices, file=sys.stderr)
        return 2
    try:
        doc = json.load(open(a.choices, encoding="utf-8"))
    except ValueError as e:
        print("FEJL: %s er ikke gyldig JSON (%s) — ret kommaer/anførselstegn efter håndredigering." % (a.choices, e), file=sys.stderr)
        print("ERROR: %s is not valid JSON (%s)." % (a.choices, e), file=sys.stderr)
        return 2
    staged = {}
    for slot, c in sorted(doc.get("choices", {}).items()):
        if c.get("status") not in BUILD_STATUS or not c.get("source"):
            continue
        pack, rel = c["source"].split("/", 1)
        if not os.path.exists(os.path.join(Q, pack, rel)):
            print("  missing in quarantine:", c["source"])
            continue
        staged.setdefault(pack, {"models": {}, "animations": {}, "atlas": []})["models"][slot] = copy(pack, rel)
    for fam, an in sorted(doc.get("animations", {}).items()):
        if an.get("status") not in BUILD_STATUS:
            continue
        for state, src in an.get("states", {}).items():
            pack, rel = src.split("/", 1)
            if not os.path.exists(os.path.join(Q, pack, rel)):
                print("  missing in quarantine:", src)
                continue
            staged.setdefault(pack, {"models": {}, "animations": {}, "atlas": []})["animations"].setdefault(fam, {})[state] = copy(pack, rel)
    for pack, files in staged.items():
        files["atlas"] = [copy(pack, rel) for rel in atlas_files(pack)]
        with open(os.path.join(IMPORTED, pack, "staged.json"), "w", encoding="utf-8") as fh:
            json.dump(files, fh, indent=1)
        print("staged %-28s %d models, %d clip sets, %d atlas textures -> assets/imported/%s/"
              % (pack, len(files["models"]), len(files["animations"]), len(files["atlas"]), pack))
    if not staged:
        print("nothing to stage (no auto/approved choices with a source) / intet at kopiere: ingen valg med status auto/approved/manual og en kilde")
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
