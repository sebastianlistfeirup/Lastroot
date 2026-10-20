#!/usr/bin/env python3
"""LR-13 fallback "skift ét asset ad gangen": limits the next tools/synty/build.sh
to the slots you name, or puts one slot back on its proxy.

  python3 tools/synty/focus.py --list                 # status per slot
  python3 tools/synty/focus.py unit.B01 unit.S01      # build ONLY these next time
  python3 tools/synty/focus.py --revert unit.B01      # back to the proxy (undo)

Focus: the named slots get "status": "approved"; every other "auto" choice becomes
"weak" (kept in the list, not built until you approve it; a new match.py run
proposes it again). Slots already built stay mapped, so earlier approved slots keep
their model. --revert sets the choice to "skip" and removes the slot from
data/art/slot_scenes.json, so the game shows the proxy again. Only names and
choices are edited (both files are safe to commit); no model file is touched.
"""
import argparse, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHOICES = os.path.join(ROOT, "data", "art", "synty_choices.json")
SCENES = os.path.join(ROOT, "data", "art", "slot_scenes.json")


def load(path, what):
    if not os.path.exists(path):
        print("FEJL: %s findes ikke. Kør først tools/synty/unpack.py og tools/synty/match.py (docs/HOMECOMING.md)." % what, file=sys.stderr)
        print("ERROR: %s not found. Run unpack.py and match.py first." % what, file=sys.stderr)
        raise SystemExit(2)
    try:
        return json.load(open(path, encoding="utf-8"))
    except ValueError as e:
        print("FEJL: %s er ikke gyldig JSON (%s)" % (what, e), file=sys.stderr)
        raise SystemExit(2)


def save(path, doc):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=1, ensure_ascii=False)
        fh.write("\n")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("slots", nargs="*", help="slot ids, e.g. unit.B01 stage.floor_roots")
    ap.add_argument("--revert", action="store_true", help="put the named slots back on their proxy")
    ap.add_argument("--list", action="store_true", help="print status per slot and exit")
    ap.add_argument("--choices", default=CHOICES)
    a = ap.parse_args()
    doc = load(a.choices, "data/art/synty_choices.json")
    choices = doc.setdefault("choices", {})
    mapped = {}
    if os.path.exists(SCENES):
        mapped = load(SCENES, "data/art/slot_scenes.json").get("scenes", {})
    if a.list or not a.slots:
        for sid in sorted(choices):
            c = choices[sid]
            print("%-24s %-9s %-6s %s" % (sid, c.get("status", ""), "built" if sid in mapped else "proxy", c.get("source", "")))
        return 0
    unknown = [s for s in a.slots if s not in choices]
    if unknown:
        print("FEJL: ukendte slots: %s (se --list)" % ", ".join(unknown), file=sys.stderr)
        return 2
    if a.revert:
        for sid in a.slots:
            choices[sid]["status"] = "skip"
        save(a.choices, doc)
        note = "ingen wrapper var bygget"
        if os.path.exists(SCENES):
            sdoc = load(SCENES, "data/art/slot_scenes.json")
            for sid in a.slots:
                sdoc.get("scenes", {}).pop(sid, None)
                sdoc.get("heights", {}).pop(sid, None)
            save(SCENES, sdoc)
            note = "fjernet fra data/art/slot_scenes.json"
        print("tilbage til proxy: %s (status skip; %s). Start spillet/galleriet igen." % (", ".join(a.slots), note))
        return 0
    missing = [s for s in a.slots if not choices[s].get("source")]
    if missing:
        print("FEJL: ingen kildefil valgt for %s: skriv \"source\": \"<pakke>/<sti>.fbx\" i synty_choices.json først" % ", ".join(missing), file=sys.stderr)
        return 2
    demoted = 0
    for sid, c in choices.items():
        if sid in a.slots:
            c["status"] = "approved"
        elif c.get("status") == "auto":
            c["status"] = "weak"
            demoted += 1
    save(a.choices, doc)
    print("fokus: %s -> approved; %d andre auto-valg sat til weak (bygges ikke). Næste: tools/synty/build.sh" % (", ".join(a.slots), demoted))
    return 0


if __name__ == "__main__":
    sys.exit(main())
