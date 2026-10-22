#!/usr/bin/env python3
"""Preflight for the LASTROOT asset pipeline (docs/HOMECOMING.md, step 2).

Read-only: checks the tools, what is unpacked in quarantine, the state of
data/art/synty_choices.json, Mixamo file naming, and that no purchased file is
tracked by git (the repo is public). Changes nothing.

  python3 tools/synty/doctor.py          # exit 0 = no FEJL/ERROR lines
Python 3 stdlib only. GODOT_BIN overrides the Godot binary.
"""
import json, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
Q = os.path.join(ROOT, "assets", "quarantine")
CHOICES = os.path.join(ROOT, "data", "art", "synty_choices.json")
SETS = os.path.join(ROOT, "data", "art", "animation_sets.json")
GODOT = os.environ.get("GODOT_BIN", "godot")
HUMANOID_STATES = ["idle", "summon", "attack", "cast", "hit", "death", "defend", "victory", "move"]
MODEL_EXT = (".fbx", ".glb", ".gltf", ".obj")

errors = 0


def line(kind, da, en=""):
    global errors
    if kind == "FEJL":
        errors += 1
    tag = {"OK": "OK      ", "NB": "NB      ", "FEJL": "FEJL    "}[kind]
    print(tag + da + ((" / " + en) if en else ""))


def run(cmd):
    try:
        return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None


def check_tools():
    r = run([GODOT, "--version"])
    if r is None or r.returncode != 0:
        line("FEJL", "Godot findes ikke ('%s'). Installér 4.7.1-stable eller sæt GODOT_BIN." % GODOT, "godot not found")
    else:
        v = r.stdout.strip().splitlines()[0] if r.stdout.strip() else "?"
        line("OK" if v.startswith("4.7.1") else "NB", "Godot " + v + ("" if v.startswith("4.7.1") else " (projektet er låst til 4.7.1-stable, docs/VERSION_MATRIX.md)"))
    try:
        import PIL  # noqa: F401
        line("OK", "Pillow findes (tools/capture_all.sh kan lave kontaktark)")
    except ImportError:
        line("NB", "Pillow mangler: pip install pillow (kun nødvendig for tools/capture_all.sh)", "Pillow missing")
    if sys.platform.startswith("linux"):
        line("OK" if shutil.which("xvfb-run") else "NB", "xvfb-run " + ("findes" if shutil.which("xvfb-run") else
             "mangler (kun nødvendig for screenshots uden skærm; på din egen maskine kan du køre scenerne direkte)"))


def keywords():
    try:
        return json.load(open(SETS, encoding="utf-8"))["keywords"]
    except (OSError, ValueError, KeyError):
        return {}


def check_quarantine():
    if not os.path.isdir(Q) or not any(os.path.exists(os.path.join(Q, p, "manifest.json")) for p in os.listdir(Q)):
        line("NB", "ingen pakker i assets/quarantine/ endnu: kør python3 tools/synty/unpack.py <pakke> (se docs/HOMECOMING.md)",
             "nothing unpacked yet")
        return
    kw = keywords()
    for pack in sorted(os.listdir(Q)):
        mf = os.path.join(Q, pack, "manifest.json")
        if not os.path.exists(mf):
            continue
        try:
            m = json.load(open(mf, encoding="utf-8"))
        except ValueError:
            line("FEJL", "%s/manifest.json er ødelagt: kør unpack.py igen" % pack)
            continue
        line("OK", "pakke %-34s %4d modeller, %4d teksturer" % (pack, m.get("models", 0), m.get("textures", 0)))
        if "mixamo" in pack.lower():
            for f in m.get("files", []):
                stem = os.path.splitext(os.path.basename(f["path"]))[0]
                st = "_".join(w for w in re.split(r"[^a-z0-9]+", stem.lower()) if w)
                if f["path"].lower().endswith(MODEL_EXT) and not any(k in st for ks in kw.values() for k in ks):
                    line("NB", "Mixamo-fil '%s' matcher ingen tilstand: omdøb til Mixamo-navnet (fx 'Breathing Idle.fbx')" % f["path"])


def check_choices():
    if not os.path.exists(CHOICES):
        line("NB", "data/art/synty_choices.json findes ikke endnu: kør python3 tools/synty/apply_selection.py efter unpack.py "
             "(det bindende valg; match.py er kun reserve)", "no choices yet")
        return
    try:
        doc = json.load(open(CHOICES, encoding="utf-8"))
    except ValueError as e:
        line("FEJL", "synty_choices.json er ikke gyldig JSON (%s)" % e, "invalid JSON")
        return
    counts = {}
    for sid, c in doc.get("choices", {}).items():
        counts[c.get("status", "?")] = counts.get(c.get("status", "?"), 0) + 1
        src = c.get("source", "")
        if src and c.get("status") in ("auto", "approved", "manual"):
            pack, _, rel = src.partition("/")
            if not os.path.exists(os.path.join(Q, pack, rel)):
                line("FEJL", "%s peger på %s, som ikke findes i karantæne (pakket ud på en anden maskine?)" % (sid, src))
    line("OK", "valg pr. status: " + ", ".join("%s %d" % kv for kv in sorted(counts.items())))
    if counts.get("weak"):
        line("NB", "%d 'weak' valg bygges først, når du sætter \"status\": \"approved\"" % counts["weak"])
    states = doc.get("animations", {}).get("humanoid", {}).get("states", {})
    missing = [s for s in HUMANOID_STATES if s not in states]
    if missing:
        line("NB", "humanoide klip mangler for: %s (procedural bevægelse bruges i stedet; docs/ASSET_MAP.md §Animation)" % ", ".join(missing))
    else:
        line("OK", "alle 9 humanoide tilstande har et klip")


def check_selection():
    r = run([sys.executable, os.path.join(ROOT, "tools", "synty", "apply_selection.py"), "--check"])
    if r is None:
        line("NB", "kunne ikke køre apply_selection.py --check")
    elif r.returncode == 0:
        line("OK", r.stdout.strip().splitlines()[-1] if r.stdout.strip() else "synty_selection ok")
    else:
        line("FEJL", "data/art/synty_selection.json er ugyldig: " + (r.stderr.strip().splitlines() or ["?"])[0], "invalid selection")
    # Realmrend lesson: a Synty Godot build ships Assets/<Pack>/...; copied into the project root on
    # Windows it merges into Lastroot's assets/ folder (case-insensitive) OUTSIDE the gitignored folders.
    for d in ("assets/PolygonFantasyKingdom", "assets/Synty", "assets/PolygonDungeon", "assets/PolygonDarkFantasy"):
        if os.path.isdir(os.path.join(ROOT, d)):
            line("FEJL", "'%s' ligner et kopieret Synty Godot-projekt i repoet (ikke gitignored!). Flyt det ud; brug kun unpack.py." % d,
                 "vendor Godot project copied into the repo")


def check_git():
    r = run(["git", "ls-files", "assets/quarantine", "assets/imported"])
    if r is None or r.returncode != 0:
        line("NB", "git ikke tilgængelig: kunne ikke tjekke at købte filer er udenfor git")
        return
    tracked = [p for p in r.stdout.split() if not p.endswith("README.md")]
    if tracked:
        line("FEJL", "købte filer er tracket af git (repoet er OFFENTLIGT): %s ... -> git rm --cached <fil>" % ", ".join(tracked[:3]),
             "purchased files tracked by git")
    else:
        line("OK", "ingen købte filer i git (assets/quarantine, assets/imported)")
    r = run(["git", "status", "--porcelain", "--", "assets", "art", "evidence/captures"])
    if r is not None:
        bad = [l for l in r.stdout.splitlines() if re.search(r"\.(fbx|unitypackage|tga|psd)$", l, re.I)]
        if bad:
            line("FEJL", "uncommittede vendorfiler synlige for git: " + "; ".join(bad[:3]))


def main() -> int:
    print("LASTROOT asset-doctor (læser kun, ændrer intet)")
    check_tools()
    check_quarantine()
    check_selection()
    check_choices()
    check_git()
    print("resultat: %s" % ("klar" if errors == 0 else "%d FEJL — ret dem før tools/synty/build.sh" % errors))
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
