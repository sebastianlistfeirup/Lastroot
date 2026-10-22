#!/usr/bin/env python3
"""Finds (and with --fix repairs) duplicate Godot UIDs between vendor Godot projects.

Lesson from Realmrend (tools/fix_vendor_uid_collision.ps1, docs/reviews/R15_codex_independent_review.md):
the Synty Godot builds of POLYGON Fantasy Kingdom and POLYGON Dark Fantasy both ship
Models/Collision/Synty_Character_Collider.tres with the SAME uid (uid://cj5gwdnnnm3q3).
Copied into one Godot project, the editor warns about a duplicate UID and may resolve the
reference to the wrong pack's file. The PowerShell fix was hard-wired to that one file
and 13 references; this is the general, cross-platform version.

Only relevant when the Godot builds' own .tscn/.tres/.res are opened in ONE Godot project
(e.g. a separate vendor-browse project). Lastroot's pipeline (unpack.py) never copies
those files, so the game project itself does not need it.

  python3 tools/synty/fix_vendor_uid_collision.py <project_or_folder> [more folders]   # report only
  python3 tools/synty/fix_vendor_uid_collision.py <project> --fix                        # rewrite duplicates

A UID is "declared" by a resource header ([gd_resource ... uid="uid://x"], [gd_scene ...]),
an .import file (uid="uid://x" in [remap]) or a <file>.uid sidecar. For each duplicated UID
the first declaring file (sorted path; --keep <substring> wins) keeps it; every other file
gets a fresh UID, and only references of the form uid="OLD" path="res://<that file>" are
rewritten (the other pack's references stay correct). Idempotent; vendor archives are never
touched — run it on the extracted copy. Exit: 0 no duplicates (or fixed) · 1 duplicates
found (report mode) · 2 bad input.
"""
import argparse, os, random, re, string, sys

TEXT_EXT = (".tscn", ".tres", ".import", ".uid", ".gd", ".godot", ".cfg")
HEADER = re.compile(r'^\[(gd_resource|gd_scene)\b[^\]]*?\buid="(uid://[a-z0-9]+)"', re.M)
IMPORT_UID = re.compile(r'^uid="(uid://[a-z0-9]+)"', re.M)
ALPHABET = string.ascii_lowercase + string.digits


def project_root(path):
    p = os.path.abspath(path)
    while True:
        if os.path.exists(os.path.join(p, "project.godot")):
            return p
        parent = os.path.dirname(p)
        if parent == p:
            return os.path.abspath(path)
        p = parent


def res_path(root, f):
    return "res://" + os.path.relpath(f, root).replace(os.sep, "/")


def read(f):
    with open(f, encoding="utf-8", errors="surrogateescape") as fh:
        return fh.read()


def write(f, text):
    with open(f, "w", encoding="utf-8", errors="surrogateescape", newline="") as fh:
        fh.write(text)


def declarations(folders):
    """[(uid, declaring_file, resource_file)] — resource_file is what res:// references point at."""
    out = []
    for folder in folders:
        for base, dirs, files in os.walk(folder):
            dirs[:] = [d for d in dirs if d != ".godot"]
            for name in files:
                f = os.path.join(base, name)
                if name.endswith(".uid"):
                    m = re.match(r"\s*(uid://[a-z0-9]+)", read(f))
                    if m:
                        out.append((m.group(1), f, f[:-4]))
                elif name.endswith(".import"):
                    m = IMPORT_UID.search(read(f))
                    if m:
                        out.append((m.group(1), f, f[: -len(".import")]))
                elif name.endswith((".tscn", ".tres")):
                    m = HEADER.search(read(f))
                    if m:
                        out.append((m.group(2), f, f))
    return out


def new_uid(taken):
    while True:
        u = "uid://" + "".join(random.choice(ALPHABET) for _ in range(13))
        if u not in taken:
            taken.add(u)
            return u


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("folders", nargs="+")
    ap.add_argument("--fix", action="store_true", help="rewrite the duplicates (default: report only)")
    ap.add_argument("--keep", default="", help="path substring whose file keeps the original UID (e.g. PolygonFantasyKingdom)")
    ap.add_argument("--root", help="Godot project root for res:// paths (default: nearest project.godot)")
    a = ap.parse_args()
    for f in a.folders:
        if not os.path.isdir(f):
            print("FEJL: mappen '%s' findes ikke / folder not found" % f, file=sys.stderr)
            return 2
    root = os.path.abspath(a.root) if a.root else project_root(a.folders[0])
    decl = declarations(a.folders)
    by_uid = {}
    for uid, f, res in decl:
        by_uid.setdefault(uid, {})
        by_uid[uid].setdefault(os.path.abspath(res), []).append(f)
    dups = {u: v for u, v in by_uid.items() if len(v) > 1}
    print("uid-scan: %d deklarationer, %d unikke uid, %d dubletter (rod %s)" % (len(decl), len(by_uid), len(dups), root))
    if not dups:
        return 0
    taken = set(by_uid)
    text_files = [os.path.join(b, n) for folder in a.folders for b, d, fs in os.walk(folder) if ".godot" not in b.split(os.sep)
                  for n in fs if n.endswith(TEXT_EXT)]
    changed = 0
    for uid, resources in sorted(dups.items()):
        order = sorted(resources, key=lambda r: (a.keep == "" or a.keep not in r, r))
        print("DUBLET %s:" % uid)
        print("   beholder  %s" % res_path(root, order[0]))
        for res in order[1:]:
            fresh = new_uid(taken)
            print("   %s %s -> %s" % ("ny uid  " if a.fix else "skal ændres", res_path(root, res), fresh if a.fix else "(kør med --fix)"))
            if not a.fix:
                continue
            for f in resources[res]:  # the declaration(s)
                t = read(f)
                write(f, t.replace('uid="%s"' % uid, 'uid="%s"' % fresh, 1) if not f.endswith(".uid") else t.replace(uid, fresh, 1))
                changed += 1
            old_ref = 'uid="%s" path="%s"' % (uid, res_path(root, res))
            new_ref = 'uid="%s" path="%s"' % (fresh, res_path(root, res))
            for f in text_files:
                t = read(f)
                if old_ref in t:
                    write(f, t.replace(old_ref, new_ref))
                    changed += 1
    if a.fix:
        again = [u for u, v in _group(declarations(a.folders)).items() if len(v) > 1]
        print("rettet: %d filer ændret; tilbage: %d dubletter. Kør derefter: godot --headless --path <projekt> --import" % (changed, len(again)))
        return 0 if not again else 1
    return 1


def _group(decl):
    g = {}
    for uid, _f, res in decl:
        g.setdefault(uid, set()).add(os.path.abspath(res))
    return g


if __name__ == "__main__":
    sys.exit(main())
