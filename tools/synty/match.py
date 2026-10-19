#!/usr/bin/env python3
"""Proposes a model for every LASTROOT visual slot from the packs in quarantine,
and animation clips per rig family (humanoid: Mixamo/Synty clip files).

Uses the per-slot search patterns in data/art/vendor_suggestions.json:
glob patterns (SM_Env_Rock*, *Deer*) score by their order, plain words score per
matching word, a pack-name match and "_01" variants get a small bonus, and a
model already proposed for another slot is slightly penalised.

Writes data/art/synty_choices.json — only file NAMES and choices, never files, so it
is safe to commit. Entries you set to "status": "approved" or "manual" are kept on
re-runs; "skip" leaves a slot on its proxy. "auto" = confident name match (built),
"weak" = one shared word only (listed, not built until approved), "none" = nothing.

Per slot you may add: "rotation_y" (default 180 for units/enemies: Synty, PolyPerfect
and Mixamo characters usually face +Z after import — verify in RigLab), "fit",
"extra_scale", "align" ("base"/"top").

  python3 tools/synty/match.py            # propose / refresh
  python3 tools/synty/match.py --report   # print only
"""
import argparse, fnmatch, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
Q = os.path.join(ROOT, "assets", "quarantine")
SUGG = os.path.join(ROOT, "data", "art", "vendor_suggestions.json")
SLOTS = os.path.join(ROOT, "data", "art", "asset_slots.json")
SETS = os.path.join(ROOT, "data", "art", "animation_sets.json")
OUT = os.path.join(ROOT, "data", "art", "synty_choices.json")
MODEL_EXT = (".fbx", ".glb", ".gltf", ".obj")
KEEP_STATUS = ("approved", "manual", "skip")
WEAK_BELOW = 50


def words(s):
    return [w for w in re.split(r"[^a-z0-9]+", s.lower()) if w]


def inventory(only=None):
    out = []
    if not os.path.isdir(Q):
        return out
    for pack in sorted(os.listdir(Q)):
        if only and pack not in only:
            continue
        mf = os.path.join(Q, pack, "manifest.json")
        if not os.path.exists(mf):
            continue
        for f in json.load(open(mf, encoding="utf-8"))["files"]:
            p = f["path"]
            out.append((pack, p, os.path.splitext(os.path.basename(p))[0]))
    return out


def is_animation(rel):
    """Clip-only files: Mixamo downloads, Synty animation packs (A_*/Anim folders)."""
    parts = [x.lower() for x in rel.replace("\\", "/").split("/")[:-1]]
    stem = os.path.splitext(os.path.basename(rel))[0].lower()
    folder = any(x in ("anim", "anims", "animation", "animations", "mixamo") or x.startswith(("animation", "mixamo")) for x in parts)
    return rel.lower().endswith(MODEL_EXT) and (folder or stem.startswith(("a_", "anim_")))


def score(spec, pack, stem):
    best = 0
    for i, pat in enumerate(spec.get("search", [])):
        if any(ch in pat for ch in "*?"):
            if fnmatch.fnmatch(stem.lower(), pat.lower()):
                best = max(best, 100 - 12 * i)
        else:
            hit = sum(1 for w in words(pat) if len(w) > 2 and w in words(stem))
            best = max(best, hit * 18)
    if best == 0:
        return 0
    packwords = [w for p in spec.get("packs", []) for w in words(p) if w not in ("synty", "polygon", "polyperfect", "low", "poly", "pack", "fantasy")]
    if any(w in words(pack) for w in packwords):
        best += 12
    if re.search(r"_0?1$", stem):
        best += 5
    return best


def propose(slots, sugg, inv, previous):
    used = {}
    for c in previous.values():
        if c.get("status") in KEEP_STATUS and c.get("source"):
            used[c["source"]] = used.get(c["source"], 0) + 1
    out = {}
    for sid, slot in slots.items():
        prev = previous.get(sid, {})
        if prev.get("status") in KEEP_STATUS:
            out[sid] = prev
            continue
        if slot.get("kind") == "fx":
            out[sid] = {"source": "", "status": "manual", "note": "Particle FX are rebuilt in Godot (fx_builder.gd); reuse only pack textures."}
            continue
        spec = sugg.get(sid, {})
        ranked = []
        for pack, rel, stem in inv:
            if not rel.lower().endswith(MODEL_EXT):
                continue
            s = score(spec, pack, stem)
            if s > 0:
                src = pack + "/" + rel
                ranked.append((s - 8 * used.get(src, 0), src))
        ranked.sort(key=lambda t: (-t[0], t[1]))
        if not ranked:
            out[sid] = {"source": "", "status": "none", "note": "no match in quarantine; keep the proxy or choose by hand"}
            continue
        src = ranked[0][1]
        used[src] = used.get(src, 0) + 1
        c = {"source": src, "score": ranked[0][0], "status": "auto" if ranked[0][0] >= WEAK_BELOW else "weak",
             "alternatives": [r[1] for r in ranked[1:5]]}
        if slot.get("kind") in ("unit", "enemy"):
            c["rotation_y"] = 180
        out[sid] = c
    return out


def propose_animations(inv, keywords, previous):
    """Rig family 'humanoid' -> {state: clip file}. Quadrupeds use their model's own clips."""
    anims = sorted([(p, r, s) for p, r, s in inv if is_animation(r)], key=lambda t: t[2])
    out = {}
    prev = previous.get("humanoid", {})
    if prev.get("status") in KEEP_STATUS:
        out["humanoid"] = prev
        return out
    states = {}
    for state, kws in keywords.items():
        for pack, rel, stem in anims:
            st = "_".join(words(stem))
            if any(k in st for k in kws):
                states[state] = pack + "/" + rel
                break
    if states:
        out["humanoid"] = {"status": "auto", "states": states}
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--packs", nargs="*")
    a = ap.parse_args()
    slots = json.load(open(SLOTS, encoding="utf-8"))["slots"]
    sugg = json.load(open(SUGG, encoding="utf-8"))["slots"]
    keywords = json.load(open(SETS, encoding="utf-8"))["keywords"]
    prev_doc = json.load(open(a.out, encoding="utf-8")) if os.path.exists(a.out) else {}
    inv = inventory(a.packs)
    model_inv = [t for t in inv if not is_animation(t[1])]
    choices = propose(slots, sugg, model_inv, prev_doc.get("choices", {}))
    animations = propose_animations(inv, keywords, prev_doc.get("animations", {}))
    counts = {}
    for c in choices.values():
        counts[c["status"]] = counts.get(c["status"], 0) + 1
    for sid, c in choices.items():
        if c.get("source"):
            print("%-22s %-7s %s" % (sid, c["status"], c["source"]))
    for fam, an in animations.items():
        print("%-22s anim    %s" % ("anim." + fam, ", ".join(sorted(an["states"]))))
    print("packs: %d · files: %d · %s" % (len({p for p, _r, _s in inv}), len(inv), counts))
    if not a.report:
        doc = {"_note": "Slot -> chosen file (path inside assets/quarantine). Only names, never files: safe to commit. "
                        "status approved/manual locks a choice, skip keeps the proxy. Then: tools/synty/build.sh",
               "choices": choices, "animations": animations}
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
        with open(a.out, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, indent=1, ensure_ascii=False)
            fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
