#!/usr/bin/env python3
"""LASTROOT localization extractor.

English is the source language and the key (D-03); localization/translations.csv
has the columns en,da. Sources scanned:
  1. Loc.t("...") literals in every .gd file of the repo (scripts/, scenes/,
     tools/, addons/; tests/ is skipped)
  2. Values of label dictionaries listed in DICT_NAMES (const/var NAME := {...})
  3. Player-facing reason strings returned by the run/battle reducers
     (`return "..."` without format codes) - the UI shows them via Loc.t(reason)
  4. data/definitions/catalog.json: every rules `text` (Loc.field prefers the
     table over the terse spec text_da, so Danish shows real upgraded numbers),
     names without name_da, plus floor names (used via Loc.t)

Existing Danish cells are kept, new keys are added, keys that no longer exist
are dropped. --check writes nothing and exits 1 if any key is missing from the
CSV, lacks Danish, or a translation changes a placeholder (%d, %s, {name}).

Usage: python3 tools/loc_extract.py [--check]
"""
import csv
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(ROOT, "localization", "translations.csv")
LOC_CALL = re.compile(r'Loc\.t\(\s*"((?:[^"\\]|\\.)*)"\s*\)')
PAIR = re.compile(r'"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"')
RETURN_STR = re.compile(r'return\s+"((?:[^"\\]|\\.)+)"')
# Save errors shown in the damaged-save dialog (SaveCodec._fail / SaveService "error").
SAVE_MSG = re.compile(r'(?:_fail\(\s*"[a-z_]+"\s*,\s*|"error":\s*|\belse\s+)"((?:[^"\\]|\\.)+)"')
SAVE_FILES = ["scripts/save/save_codec.gd", "scripts/autoload/save_service.gd"]
PLACEHOLDER = re.compile(r"%[-+0-9.]*[dsfxX%]|\{[a-z_]+\}")
DICT_NAMES = ["FACTION_PITCH", "FACTION_NAME", "stat_names"]
REASON_FILES = ["scripts/domain/run/run_reducer.gd", "scripts/domain/battle/battle_reducer.gd",
                "scripts/autoload/game_session.gd"]
SKIP_DIRS = {".godot", ".git", ".claude", "tests", "archive"}


def unescape(s):
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def gd_files():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        rel = os.path.relpath(dirpath, ROOT)
        top = rel.split(os.sep)[0]
        if top in SKIP_DIRS:
            dirnames[:] = []
            continue
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in sorted(filenames):
            if f.endswith(".gd"):
                yield os.path.join(dirpath, f)


def dict_body(src, name):
    m = re.search(r"(?:const|var)\s+%s\s*(?::\s*\w+\s*)?:?=\s*\{" % re.escape(name), src)
    if not m:
        return None
    depth, i, in_str = 1, m.end(), False
    while i < len(src) and depth:
        ch = src[i]
        if in_str:
            if ch == "\\":
                i += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        i += 1
    return src[m.end():i - 1]


def from_code():
    out = {}
    for path in gd_files():
        rel = os.path.relpath(path, ROOT)
        src = open(path, encoding="utf-8").read()
        for m in LOC_CALL.finditer(src):
            out.setdefault(unescape(m.group(1)), rel)
        for name in DICT_NAMES:
            body = dict_body(src, name)
            if body:
                for pm in PAIR.finditer(body):
                    out.setdefault(unescape(pm.group(2)), "%s:%s" % (rel, name))
    for rel in REASON_FILES:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            continue
        for m in RETURN_STR.finditer(open(p, encoding="utf-8").read()):
            s = unescape(m.group(1))
            if "%" in s or not s[:1].isupper():
                continue  # formatted reasons fall back to English; ids are not text
            out.setdefault(s, rel + ":reason")
    for rel in SAVE_FILES:
        p = os.path.join(ROOT, rel)
        if os.path.exists(p):
            for m in SAVE_MSG.finditer(open(p, encoding="utf-8").read()):
                out.setdefault(unescape(m.group(1)), rel + ":save")
    return out


def from_data():
    out = {}
    path = os.path.join(ROOT, "data", "definitions", "catalog.json")
    data = json.load(open(path, encoding="utf-8"))

    def walk(o):
        if isinstance(o, dict):
            for key in ("name", "text"):
                # Names keep their catalog name_da; rules text always goes
                # through the table (player wording with {placeholders}).
                if isinstance(o.get(key), str) and o[key].strip() and (key == "text" or key + "_da" not in o):
                    out.setdefault(o[key], "catalog.json")
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    walk(data)
    for f in data.get("floors", []):
        out.setdefault(f["name"], "catalog.json:floors")
    return out


def load_existing():
    if not os.path.exists(CSV_PATH):
        return {}
    with open(CSV_PATH, encoding="utf-8", newline="") as fh:
        return {row["en"]: row.get("da", "") or "" for row in csv.DictReader(fh)}


def placeholders(s):
    return sorted(PLACEHOLDER.findall(s))


def main():
    check = "--check" in sys.argv
    keys = {}
    keys.update(from_data())
    keys.update(from_code())
    existing = load_existing()
    missing_rows = sorted(k for k in keys if k not in existing)
    dropped = sorted(k for k in existing if k not in keys)
    untranslated = sorted(k for k in keys if not existing.get(k, ""))
    bad_ph = sorted(k for k in keys if existing.get(k) and placeholders(k) != placeholders(existing[k]))
    # English only (D34): the da column is dormant, so missing Danish is reported, not a failure.
    print("loc_extract: %d keys, %d not in csv, %d dropped, %d without Danish (dormant), %d placeholder mismatches"
          % (len(keys), len(missing_rows), len(dropped), len(untranslated), len(bad_ph)))
    if check:
        for k in bad_ph[:20]:
            print("  PLACEHOLDER  %s  ->  %s" % (k[:60], existing[k][:60]))
        for k in missing_rows[:40]:
            print("  NOT IN CSV  %s  (%s)" % (k[:90], keys[k]))
        return 1 if (missing_rows or bad_ph) else 0
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        w.writerow(["en", "da"])
        for k in sorted(keys, key=lambda s: (keys[s], s)):
            w.writerow([k, existing.get(k, "")])
    for k in dropped[:20]:
        print("  dropped:", k[:90])
    return 0


if __name__ == "__main__":
    sys.exit(main())
