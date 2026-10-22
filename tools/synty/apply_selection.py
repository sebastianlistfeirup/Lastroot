#!/usr/bin/env python3
"""Turns the binding asset selection (data/art/synty_selection.json) into
data/art/synty_choices.json — the exact file match.py writes and stage.py,
build.sh and focus.py read. It replaces match.py's guessing: every slot already
has a chosen pack + file pattern (+ ordered alternatives); this tool only finds
the real path of that file in the unpacked quarantine (assets/quarantine/<pack>/
manifest.json, written by unpack.py) and reports anything missing or ambiguous.

  python3 tools/synty/apply_selection.py --check          # selection valid? covers every slot? (no packs needed)
  python3 tools/synty/apply_selection.py --dry-run        # print the plan; resolves against quarantine if present
  python3 tools/synty/apply_selection.py --archives D:/LASTROOT_vendor/Synty   # sha256 of the owned archives
  python3 tools/synty/apply_selection.py                  # resolve + write data/art/synty_choices.json
  tools/synty/build.sh                                    # then build as usual

Resolution per slot: the primary candidate, then each alternative in order; the first
pattern that matches a model file in an unpacked pack wins. A pack is an archive name
(slug = unpack.py's folder name) or a glob ("POLYGON_Fantasy_Rivals*" for a pack you
still have to download). Several matches = ambiguous: the best (FBX, "_01", shortest
path) is taken and listed. Slots with decision keep_proxy, and slots whose files are
not unpacked, are written as "skip" (proxy) with a note — never silently.

Entries you edited by hand (status approved/manual/skip without "origin": "selection",
or reverted with focus.py --revert) are kept; --force overwrites them.

Exit codes: 0 everything resolved (or --dry-run/--check ok) · 2 bad input (selection
or slots JSON, unknown slot, checksum mismatch, nothing unpacked) · 3 written, but some
selected slots/clips/archives are missing (they stay on the proxy; --allow-missing -> 0).
Python 3 stdlib only. Writes only names, never vendor files (safe to commit).
"""
import argparse, fnmatch, hashlib, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SELECTION = os.path.join(ROOT, "data", "art", "synty_selection.json")
SLOTS = os.path.join(ROOT, "data", "art", "asset_slots.json")
OUT = os.path.join(ROOT, "data", "art", "synty_choices.json")
Q = os.path.join(ROOT, "assets", "quarantine")
MODEL_EXT = (".fbx", ".glb", ".gltf", ".obj")
IMAGE_EXT = (".png", ".tga", ".jpg", ".jpeg", ".psd")
DECISIONS = ("owned", "needs_download", "keep_proxy", "generated")  # generated: docs/ASSET_GAP_WORKFLOW.md
CONFIDENCE = ("verified_in_realmrend", "pattern_only")
STATES = ("idle", "summon", "attack", "cast", "hit", "death", "defend", "victory", "move")
KEEP_STATUS = ("approved", "manual", "skip")
FX_NOTE = "Particle FX are rebuilt in Godot (fx_builder.gd); reuse only pack textures."


def slug(name):
    """Same folder name unpack.py gives an archive (keeps '*' for globs)."""
    s = re.sub(r"\.(unitypackage|zip)$", "", os.path.basename(name.rstrip("/\\")), flags=re.I)
    s = re.sub(r"[^A-Za-z0-9*]+", "_", s).strip("_")
    return s or "pack"


class Err(Exception):
    pass


def load_json(path, what):
    if not os.path.exists(path):
        raise Err("%s findes ikke (%s) / %s not found" % (what, path, what))
    try:
        return json.load(open(path, encoding="utf-8"))
    except ValueError as e:
        raise Err("%s er ikke gyldig JSON: %s / %s is not valid JSON" % (what, e, what))


def say(msg_da, msg_en=""):
    print(msg_da + ((" / " + msg_en) if msg_en else ""))


# ---------------------------------------------------------------- validation

def candidates(spec):
    """Primary + alternatives as [{pack, file, confidence, decision}], in resolve order."""
    out = []
    if spec.get("pack") and spec.get("file"):
        out.append({"pack": spec["pack"], "file": spec["file"], "confidence": spec.get("confidence", "pattern_only"),
                    "decision": spec.get("decision")})
    for alt in spec.get("alternatives", []):
        if isinstance(alt, dict) and alt.get("pack") and alt.get("file"):
            out.append({"pack": alt["pack"], "file": alt["file"], "confidence": alt.get("confidence", "pattern_only"),
                        "decision": alt.get("decision", "owned" if not _is_glob(alt["pack"]) else "needs_download")})
    return out


def _is_glob(p):
    return any(ch in p for ch in "*?")


def validate(sel, slots):
    """Returns a list of problems (empty = valid)."""
    probs = []
    packs = sel.get("packs", {})
    archives = {p.get("archive") for p in packs.values() if p.get("archive")}
    globs = [p.get("archive_glob") for p in packs.values() if p.get("archive_glob")]

    def known(pack):
        return pack in archives or pack in globs

    ssel = sel.get("slots", {})
    for sid in slots:
        if sid not in ssel:
            probs.append("slot %s mangler i synty_selection.json / missing from selection" % sid)
    for sid, spec in ssel.items():
        if sid not in slots:
            probs.append("ukendt slot %s (findes ikke i asset_slots.json) / unknown slot" % sid)
            continue
        d = spec.get("decision")
        if d not in DECISIONS:
            probs.append("%s: decision '%s' skal være en af %s" % (sid, d, "/".join(DECISIONS)))
            continue
        if not spec.get("reason"):
            probs.append("%s: mangler 'reason'" % sid)
        if d == "keep_proxy":
            continue
        if d == "generated":
            # Project-built asset (image -> scan -> Godot rebuild); its scene is set on the slot.
            if not str(spec.get("scene", "")).startswith("res://art/generated/"):
                probs.append("%s: decision generated kræver 'scene' under res://art/generated/" % sid)
            continue
        if not spec.get("pack") or not spec.get("file"):
            probs.append("%s: decision %s kræver 'pack' og 'file'" % (sid, d))
        if spec.get("confidence") not in CONFIDENCE:
            probs.append("%s: confidence '%s' skal være %s" % (sid, spec.get("confidence"), "/".join(CONFIDENCE)))
        for c in candidates(spec):
            if not known(c["pack"]):
                probs.append("%s: pakke '%s' står ikke i 'packs' / pack not declared" % (sid, c["pack"]))
        if slots[sid].get("kind") in ("unit", "enemy") and slots[sid].get("rig_family") == "humanoid" and not spec.get("clips"):
            probs.append("%s: humanoid uden 'clips' (state -> clipfil)" % sid)
    for state, spec in sel.get("animation_sets", {}).get("humanoid", {}).get("states", {}).items():
        if state not in STATES:
            probs.append("animation_sets.humanoid: ukendt tilstand %s" % state)
        for c in spec.get("candidates", []):
            if c.get("pack") and not known(c["pack"]):
                probs.append("animation %s: pakke '%s' står ikke i 'packs'" % (state, c["pack"]))
    return probs


# ---------------------------------------------------------------- quarantine

def quarantine(qroot):
    """{slug: [relative file paths]} for every unpacked pack (manifest.json)."""
    inv = {}
    if not os.path.isdir(qroot):
        return inv
    for pack in sorted(os.listdir(qroot)):
        mf = os.path.join(qroot, pack, "manifest.json")
        if not os.path.exists(mf):
            continue
        try:
            doc = json.load(open(mf, encoding="utf-8"))
            inv[pack] = [f["path"] for f in doc.get("files", [])]
        except (ValueError, KeyError, TypeError) as e:
            print("NB: %s/manifest.json kunne ikke læses (%s) — pakken springes over / skipped" % (pack, e))
    return inv


def packs_for(pack, inv):
    """Quarantine folders matching an archive name or a glob (case-insensitive)."""
    want = slug(pack).lower()
    if _is_glob(want):
        return [p for p in inv if fnmatch.fnmatch(p.lower(), want)]
    return [p for p in inv if p.lower() == want]


def match_files(pattern, files, exts):
    """Files whose path (pattern with '/') or basename (pattern without '/') matches."""
    pat = pattern.lower().replace("\\", "/")
    if "/" in pat and not pat.startswith(("*", "/")):
        pat = "*/" + pat  # "Characters/SK_Chr_X.fbx" may sit under any top folder
    out = []
    for f in files:
        fl = f.lower()
        if fl.endswith(exts) and fnmatch.fnmatch(("/" + fl) if "/" in pat else os.path.basename(fl), pat):
            out.append(f)
    return out


def rank(path):
    stem = os.path.splitext(os.path.basename(path))[0]
    ext = os.path.splitext(path)[1].lower()
    return (MODEL_EXT.index(ext) if ext in MODEL_EXT else 9, 0 if re.search(r"_0?1$", stem) else 1, len(path), path.lower())


def resolve(cands, inv, exts=MODEL_EXT):
    """First candidate with a match. Returns dict or None, plus tried list."""
    tried = []
    for i, c in enumerate(cands):
        hits = []
        for p in packs_for(c["pack"], inv):
            hits += [(p, f) for f in match_files(c["file"], inv[p], exts)]
        tried.append("%s :: %s -> %d" % (c["pack"], c["file"], len(hits)))
        if hits:
            hits.sort(key=lambda h: rank(h[1]))
            stems = {os.path.splitext(os.path.basename(f))[0].lower() for _p, f in hits}
            return {"index": i, "cand": c, "source": hits[0][0] + "/" + hits[0][1], "matches": len(hits),
                    "ambiguous": len(stems) > 1, "others": [p + "/" + f for p, f in hits[1:5]]}, tried
    return None, tried


# ---------------------------------------------------------------- build choices

def build(sel, slots, inv, previous, force=False):
    choices, report = {}, {"resolved": [], "missing": [], "ambiguous": [], "kept": [], "proxy": [], "fallback": []}
    prev = previous.get("choices", {})
    for sid, slot in slots.items():
        spec = sel["slots"].get(sid, {})
        old = prev.get(sid)
        if old and not force and (old.get("reverted_by_owner") or (old.get("origin") != "selection" and old.get("status") in KEEP_STATUS)):
            choices[sid] = old
            report["kept"].append(sid)
            continue
        if slot.get("kind") == "fx":
            choices[sid] = {"source": "", "status": "manual", "origin": "selection", "note": FX_NOTE}
            report["proxy"].append(sid)
            continue
        if spec.get("decision") in ("keep_proxy", "generated"):
            choices[sid] = {"source": "", "status": "skip", "origin": "selection", "note": spec.get("decision") + ": " + spec.get("reason", "")}
            report["proxy"].append(sid)
            continue
        hit, tried = resolve(candidates(spec), inv)
        if not hit:
            choices[sid] = {"source": "", "status": "skip", "origin": "selection",
                            "note": "selected file not unpacked (proxy stays): " + "; ".join(tried)}
            report["missing"].append((sid, tried, spec.get("decision")))
            continue
        c = {"source": hit["source"], "status": "approved", "origin": "selection",
             "selection": {"decision": hit["cand"].get("decision") or spec.get("decision"), "candidate": hit["index"],
                           "pattern": hit["cand"]["file"], "confidence": hit["cand"]["confidence"], "matches": hit["matches"]},
             "alternatives": hit["others"]}
        if slot.get("kind") in ("unit", "enemy"):
            c["rotation_y"] = spec.get("rotation_y", 180)
        for k in ("fit", "extra_scale", "align"):
            if k in spec:
                c[k] = spec[k]
        if spec.get("embedded_clips"):
            c["clips"] = spec["embedded_clips"]  # clip names INSIDE the model (own rigs), never file paths
        choices[sid] = c
        report["resolved"].append(sid)
        if hit["index"] > 0:
            report["fallback"].append((sid, hit["index"], hit["source"]))
        if hit["ambiguous"]:
            report["ambiguous"].append((sid, hit["matches"], hit["source"]))
    # animations: one shared humanoid library (build_wrappers.gd builds "humanoid" only)
    states, missing_states = {}, []
    hum = sel.get("animation_sets", {}).get("humanoid", {})
    for state, spec in hum.get("states", {}).items():
        cands = [c for c in spec.get("candidates", []) if c.get("pack") and c.get("file")]
        hit, tried = resolve(cands, inv, (".fbx", ".glb", ".gltf"))
        if hit:
            states[state] = hit["source"]
            if hit["ambiguous"]:
                report["ambiguous"].append(("anim." + state, hit["matches"], hit["source"]))
            if hit["index"] > 0:
                report["fallback"].append(("anim." + state, hit["index"], hit["source"]))
        else:
            missing_states.append(state)
            if not spec.get("optional"):
                report["missing"].append(("anim." + state, tried, "owned"))
    animations = {}
    old_an = previous.get("animations", {}).get("humanoid")
    if old_an and not force and old_an.get("origin") != "selection" and old_an.get("status") in KEEP_STATUS:
        animations["humanoid"] = old_an
        report["kept"].append("anim.humanoid")
    elif states:
        animations["humanoid"] = {"status": "approved", "origin": "selection", "states": states,
                                  "procedural": sorted(missing_states)}
    # atlas per used pack (stage.py puts it first, so the builder's shared material uses it)
    atlas = {}
    used = sorted({c["source"].split("/", 1)[0] for c in choices.values() if c.get("source")})
    for p in used:
        spec = next((v for v in sel.get("packs", {}).values() if v.get("archive") and slug(v["archive"]).lower() == p.lower()), None)
        if not spec or not spec.get("atlas"):
            continue
        cands = [{"pack": spec["archive"], "file": f, "confidence": "pattern_only"} for f in spec["atlas"]]
        if spec.get("sibling"):
            cands += [{"pack": spec["sibling"], "file": f, "confidence": "pattern_only"} for f in spec["atlas"]]
        hit, tried = resolve(cands, inv, IMAGE_EXT)
        if hit:
            atlas[p] = hit["source"]
        else:
            report["missing"].append(("atlas." + p, tried, "owned"))
    return choices, animations, atlas, report


# ---------------------------------------------------------------- archives

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def check_archives(sel, folder):
    """Finds each owned archive under folder (recursive), compares size + sha256."""
    found = {}
    for base, _d, files in os.walk(folder):
        for f in files:
            found.setdefault(f.lower(), os.path.join(base, f))
    bad = missing = 0
    for key, p in sorted(sel.get("packs", {}).items()):
        if not p.get("owned") or not p.get("archive"):
            continue
        path = found.get(p["archive"].lower())
        if not path:
            missing += 1
            say("MANGLER  %-55s (%s)" % (p["archive"], p.get("ledger_id", "")), "missing")
            continue
        size = os.path.getsize(path)
        if p.get("bytes") and size != p["bytes"]:
            bad += 1
            say("FEJL     %-55s størrelse %d, forventet %d" % (p["archive"], size, p["bytes"]), "size mismatch: re-download")
            continue
        digest = sha256(path)
        if p.get("sha256") and digest != p["sha256"]:
            bad += 1
            say("FEJL     %-55s sha256 %s… passer ikke med ledger" % (p["archive"], digest[:16]), "checksum mismatch: re-download")
            continue
        say("OK       %-55s sha256 ok" % p["archive"])
    for key, p in sorted(sel.get("packs", {}).items()):
        if p.get("needs_download") and p.get("archive_glob"):
            hits = [n for n in found if fnmatch.fnmatch(n, p["archive_glob"].lower() + ("" if p["archive_glob"].lower().endswith((".zip", ".unitypackage")) else "*"))]
            say("%-8s %-55s %s" % ("OK" if hits else "NB", p["archive_glob"], ("fundet: " + ", ".join(hits)) if hits else "ikke hentet endnu (valgfri: slots falder tilbage)"))
    return bad, missing


# ---------------------------------------------------------------- main

def print_plan(sel, slots, inv):
    print("%-20s %-15s %-22s %-44s %s" % ("slot", "decision", "confidence", "pack -> file", "quarantine"))
    for sid in slots:
        spec = sel["slots"].get(sid, {})
        d = spec.get("decision", "?")
        if d in ("keep_proxy", "generated") or slots[sid].get("kind") == "fx":
            print("%-20s %-15s %-22s %s" % (sid, d, "-", ("scene: " + str(spec.get("scene", ""))) if d == "generated" else "proxy: " + spec.get("reason", "")[:70]))
            continue
        hit = None
        if inv:
            hit, _t = resolve(candidates(spec), inv)
        where = ("-> " + hit["source"] + ("  [alt %d]" % hit["index"] if hit["index"] else "") + ("  [%d matches]" % hit["matches"] if hit["ambiguous"] else "")) \
            if hit else ("(ikke udpakket)" if inv else "")
        print("%-20s %-15s %-22s %-44s %s" % (sid, d, spec.get("confidence", ""), slug(spec.get("pack", "")) [:20] + " :: " + spec.get("file", ""), where))
    hum = sel.get("animation_sets", {}).get("humanoid", {}).get("states", {})
    for state, spec in hum.items():
        c = (spec.get("candidates") or [{}])[0]
        hit = resolve([x for x in spec.get("candidates", []) if x.get("pack")], inv, (".fbx", ".glb", ".gltf"))[0] if inv else None
        print("%-20s %-15s %-22s %-44s %s" % ("anim." + state, "owned" if not spec.get("optional") else "optional", c.get("confidence", ""),
                                             slug(c.get("pack", ""))[:20] + " :: " + c.get("file", ""), ("-> " + hit["source"]) if hit else ""))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--selection", default=SELECTION)
    ap.add_argument("--slots", default=SLOTS)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--quarantine", default=Q)
    ap.add_argument("--check", action="store_true", help="validate the selection only")
    ap.add_argument("--dry-run", action="store_true", help="print the plan, write nothing")
    ap.add_argument("--archives", help="folder with the downloaded archives: verify size + sha256, write nothing")
    ap.add_argument("--force", action="store_true", help="also overwrite hand-edited choices")
    ap.add_argument("--allow-missing", action="store_true", help="exit 0 even if some selected files are not unpacked")
    a = ap.parse_args()
    try:
        sel = load_json(a.selection, "data/art/synty_selection.json")
        slots = load_json(a.slots, "data/art/asset_slots.json")["slots"]
    except (Err, KeyError) as e:
        print("FEJL: %s" % e, file=sys.stderr)
        return 2
    probs = validate(sel, slots)
    if probs:
        for p in probs:
            print("FEJL: " + p, file=sys.stderr)
        print("FEJL: synty_selection.json er ugyldig (%d problemer); intet skrevet / invalid selection, nothing written" % len(probs), file=sys.stderr)
        return 2
    counts = {}
    for sid in slots:
        spec = sel["slots"][sid]
        k = "fx" if slots[sid].get("kind") == "fx" else spec["decision"] + ("/" + spec.get("confidence", "") if spec["decision"] not in ("keep_proxy", "generated") else "")
        counts[k] = counts.get(k, 0) + 1
    if a.check:
        print("synty_selection ok: %d slots · %s" % (len(slots), ", ".join("%s=%d" % kv for kv in sorted(counts.items()))))
        return 0
    if a.archives:
        if not os.path.isdir(a.archives):
            print("FEJL: mappen '%s' findes ikke / folder not found" % a.archives, file=sys.stderr)
            return 2
        bad, missing = check_archives(sel, a.archives)
        print("arkiver: %d fejl, %d mangler / archives: %d bad, %d missing" % (bad, missing, bad, missing))
        return 2 if bad else (3 if missing and not a.allow_missing else 0)
    inv = quarantine(a.quarantine)
    if a.dry_run:
        print("PLAN (dry-run, intet skrives / nothing written) · %d slots · %s" % (len(slots), ", ".join("%s=%d" % kv for kv in sorted(counts.items()))))
        if not inv:
            print("NB: ingen udpakkede pakker i %s — viser kun valget. Næste: tools/synty/unpack.py <arkiv> for hvert arkiv i docs/HOMECOMING.md §2."
                  % os.path.relpath(a.quarantine, ROOT))
        print_plan(sel, slots, inv)
        return 0
    if not inv:
        print("FEJL: ingen udpakkede pakker i %s. Kør først unpack.py for hvert arkiv (docs/HOMECOMING.md §2). %s er ikke ændret."
              % (os.path.relpath(a.quarantine, ROOT), os.path.relpath(a.out, ROOT)), file=sys.stderr)
        print("ERROR: nothing unpacked; nothing written (try --dry-run to see the plan).", file=sys.stderr)
        return 2
    previous = {}
    if os.path.exists(a.out):
        try:
            previous = json.load(open(a.out, encoding="utf-8"))
        except ValueError as e:
            print("FEJL: eksisterende %s er ugyldig JSON (%s) — ret eller slet den først" % (a.out, e), file=sys.stderr)
            return 2
    choices, animations, atlas, rep = build(sel, slots, inv, previous, a.force)
    doc = {"_note": "Generated by tools/synty/apply_selection.py from data/art/synty_selection.json (the binding choice). "
                    "Same format as match.py: only names, never files (safe to commit). status approved = built by build.sh; "
                    "skip = proxy. Edit synty_selection.json and re-run, or edit here (hand edits without origin=selection are kept).",
           "choices": choices, "animations": animations, "atlas": atlas}
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    for sid, n, src in rep["ambiguous"]:
        print("NB    tvetydig %-18s %d filer passer; valgt %s (se 'alternatives')" % (sid, n, src))
    for sid, i, src in rep["fallback"]:
        print("NB    alternativ %-16s kandidat %d brugt: %s" % (sid, i, src))
    for sid, tried, d in rep["missing"]:
        print("MANGLER %-18s (%s) prøvet: %s" % (sid, d, " | ".join(tried)))
    for sid in rep["kept"]:
        print("BEHOLDT %-18s din egen ændring bevaret (--force overskriver)" % sid)
    hum = animations.get("humanoid", {})
    print("valgt: %d slots løst, %d proxy/FX, %d mangler, %d tvetydige, %d beholdt · klip: %s · atlas: %d pakker -> %s"
          % (len(rep["resolved"]), len(rep["proxy"]), len([m for m in rep["missing"] if not m[0].startswith(("anim.", "atlas."))]),
             len(rep["ambiguous"]), len(rep["kept"]), ", ".join(sorted(hum.get("states", {}))) or "ingen",
             len(atlas), os.path.relpath(a.out, ROOT)))
    needed_missing = [m for m in rep["missing"] if m[2] != "needs_download"]
    if needed_missing and not a.allow_missing:
        print("exit 3: %d valgte ejede filer/klip/atlas ikke fundet (de bliver på proxy). Pak de manglende arkiver ud og kør igen, "
              "eller --allow-missing. / some owned selections not found." % len(needed_missing))
        return 3
    print("Næste / next: tools/synty/build.sh")
    return 0


if __name__ == "__main__":
    sys.exit(main())
