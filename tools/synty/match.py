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


CLIP_PACK_WORDS = ("mixamo", "anim", "anims", "animation", "animations", "clip", "clips")
_clip_packs = set()


def inventory(only=None, keywords=None):
    """(pack, rel, stem) for every file. Also decides which packs are clip packs."""
    out = []
    _clip_packs.clear()
    if not os.path.isdir(Q):
        return out
    for pack in sorted(os.listdir(Q)):
        if only and pack not in only:
            continue
        mf = os.path.join(Q, pack, "manifest.json")
        if not os.path.exists(mf):
            continue
        doc = json.load(open(mf, encoding="utf-8"))
        files = [f["path"] for f in doc["files"]]
        if is_clip_pack(pack, files, doc.get("kind", ""), keywords or {}):
            _clip_packs.add(pack)
        for p in files:
            out.append((pack, p, os.path.splitext(os.path.basename(p))[0]))
    return out


def is_clip_pack(pack, files, kind="", keywords=None):
    """A folder of Mixamo downloads unpacked as its own pack (unpack.py "D:/Mixamo/LASTROOT_clips"):
    the files sit at the pack root, so no "Mixamo/" folder marks them. A pack counts as clips when
    unpack.py --clips said so, its folder name says so (Mixamo, anim, clips: docs/HOMECOMING.md §3 says
    "the folder name must contain Mixamo"), or it has no textures and at
    least 60 % of its model files are named after an animation state (Breathing Idle, Punching...)."""
    if kind == "clips":
        return True
    if any(w in CLIP_PACK_WORDS or w.startswith(("mixamo", "animation")) for w in words(pack)):
        return True
    models = [f for f in files if f.lower().endswith(MODEL_EXT)]
    if not models or any(f.lower().endswith((".png", ".tga", ".jpg", ".jpeg", ".psd")) for f in files):
        return False
    kws = [k for ks in (keywords or {}).values() for k in ks]
    named = sum(1 for f in models if any(k in "_".join(words(os.path.splitext(os.path.basename(f))[0])) for k in kws))
    return named >= 0.6 * len(models)


def is_animation(rel, pack=""):
    """Clip-only files: Mixamo downloads, Synty animation packs (A_*/Anim folders), clip packs."""
    parts = [x.lower() for x in rel.replace("\\", "/").split("/")[:-1]]
    stem = os.path.splitext(os.path.basename(rel))[0].lower()
    folder = any(x in ("anim", "anims", "animation", "animations", "mixamo") or x.startswith(("animation", "mixamo")) for x in parts)
    return rel.lower().endswith(MODEL_EXT) and (folder or stem.startswith(("a_", "anim_")) or pack in _clip_packs)


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


def propose_animations(inv, keywords, previous, mixamo_names=None):
    """Rig family 'humanoid' -> {state: clip file}. Quadrupeds use their model's own clips.
    1. exact Mixamo names from animation_sets.json (sets.humanoid.mixamo: "Breathing Idle" -> idle);
    2. keywords; a file whose name also fits another state's keyword ("Standing 1H Magic Attack"
       contains "stand" = idle) loses to one that fits only this state, and a file already used
       for another state is taken only when nothing else fits; FBX wins over glTF on a tie."""
    anims = sorted([(p, r, s) for p, r, s in inv if is_animation(r, p)], key=lambda t: (t[2], not t[1].lower().endswith(".fbx")))
    out = {}
    prev = previous.get("humanoid", {})
    if prev.get("status") in KEEP_STATUS:
        out["humanoid"] = prev
        return out
    states, used = {}, {}
    norm = lambda x: "_".join(words(x))
    for state, names in (mixamo_names or {}).items():
        for n in names:
            hit = next((t for t in anims if norm(t[2]) == norm(n)), None)
            if hit and state not in states:
                states[state] = hit[0] + "/" + hit[1]
                used[states[state]] = state
    for state, kws in keywords.items():
        if state in states:
            continue
        best = None
        for pack, rel, stem in anims:
            st = norm(stem)
            hits = [i for i, k in enumerate(kws) if k in st]
            if not hits:
                continue
            src = pack + "/" + rel
            others = sum(1 for s2, k2 in keywords.items() if s2 != state and any(k in st for k in k2))
            rank = (src in used, others, min(hits))
            if best is None or rank < best[0]:
                best = (rank, src)
        if best:
            states[state] = best[1]
            used[best[1]] = state
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
    sets_doc = json.load(open(SETS, encoding="utf-8"))
    keywords = sets_doc["keywords"]
    mixamo_names = sets_doc.get("sets", {}).get("humanoid", {}).get("mixamo", {})
    prev_doc = json.load(open(a.out, encoding="utf-8")) if os.path.exists(a.out) else {}
    inv = inventory(a.packs, keywords)
    if not inv:
        where = ("packs " + ", ".join(a.packs)) if a.packs else "assets/quarantine/"
        print("FEJL: ingen udpakkede pakker i %s. Kør først: python3 tools/synty/unpack.py <pakke.unitypackage|.zip|mappe>. "
              "%s er ikke ændret; spillet bruger stadig proxies." % (where, os.path.relpath(a.out, ROOT)), file=sys.stderr)
        print("ERROR: no unpacked packs in %s. Run tools/synty/unpack.py first. Nothing was written." % where, file=sys.stderr)
        return 2
    model_inv = [t for t in inv if not is_animation(t[1], t[0])]
    choices = propose(slots, sugg, model_inv, prev_doc.get("choices", {}))
    animations = propose_animations(inv, keywords, prev_doc.get("animations", {}), mixamo_names)
    counts = {}
    for c in choices.values():
        counts[c["status"]] = counts.get(c["status"], 0) + 1
    for sid, c in choices.items():
        if c.get("source"):
            print("%-22s %-7s %s" % (sid, c["status"], c["source"]))
    for fam, an in animations.items():
        print("%-22s anim    %s" % ("anim." + fam, ", ".join(sorted(an["states"]))))
    print("packs: %d · files: %d · %s" % (len({p for p, _r, _s in inv}), len(inv), counts))
    if not animations:
        print("NB: ingen Mixamo-/animationsklip fundet (mappe 'Mixamo/' eller filnavne A_*/Anim_*). Figurerne bruger procedural bevægelse, indtil du "
              "kører unpack.py på en mappe med Mixamo-FBX. / no animation clips found: humanoids fall back to procedural motion.")
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
