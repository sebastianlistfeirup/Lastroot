#!/usr/bin/env python3
"""LR-33/35 release hygiene, safe to run any time (also part of tools/check.sh).

1. No purchased vendor files (Synty/PolyPerfect/Mixamo) tracked by git:
   nothing under assets/quarantine/ or assets/imported/ except README/.gdignore,
   no .fbx/.unitypackage/.blend/.ma/.max anywhere.
2. No secrets in tracked text files (API keys, tokens, private keys).
3. Every export preset excludes the internal folders (tests, tools, docs,
   references, ...), so reference images and design files never ship.
4. If builds exist under builds/: sha256 of every file (written with --checksums),
   and each .pck's file list is checked for internal folders, its bytes for secrets.

Writes evidence/release/release_check.json. Exit 1 on any failure.
Usage: python3 tools/release_check.py [--quiet] [--checksums]
(--checksums writes evidence/build_checksums.txt; do it for a release build.)
"""
import hashlib, json, os, re, struct, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUIET = "--quiet" in sys.argv
VENDOR_EXT = (".fbx", ".unitypackage", ".blend", ".ma", ".max", ".prefab")
VENDOR_DIRS = ("assets/quarantine/", "assets/imported/")
ALLOWED_IN_VENDOR_DIRS = ("README.md", ".gdignore", ".gitkeep")
MUST_EXCLUDE = ["tests/*", "scenes/tests/*", "tools/*", "fixtures/*", "evidence/*", "docs/*", "archive/*", "references/*", "design/*", "plan/*", "templates/*"]
SECRET_PATTERNS = {
    "aws_key": re.compile(rb"AKIA[0-9A-Z]{16}"),
    "github_token": re.compile(rb"gh[pousr]_[A-Za-z0-9]{36,}"),
    "openai_style_key": re.compile(rb"sk-[A-Za-z0-9_-]{32,}"),
    "slack_token": re.compile(rb"xox[baprs]-[A-Za-z0-9-]{10,}"),
    "private_key": re.compile(rb"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "google_api_key": re.compile(rb"AIza[0-9A-Za-z_-]{35}"),
}
TEXT_EXT = (".gd", ".py", ".sh", ".js", ".json", ".md", ".cfg", ".csv", ".tscn", ".tres", ".godot", ".txt", ".html", ".yml", ".yaml")


def tracked_files():
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=True).stdout
    return [p for p in out.decode("utf-8").split("\0") if p]


def pck_paths(data):
    """File paths in a Godot 4 .pck (format 2 or 3). Paths only: the UID cache
    inside a pack also names excluded files, so a byte search would mislead."""
    if data[:4] != b"GDPC":
        return None
    ver = struct.unpack_from("<I", data, 4)[0]
    off = 24 + 8  # magic, 4 version ints, flags, file base
    if ver >= 3:
        off = struct.unpack_from("<Q", data, off)[0]
    else:
        off += 16 * 4
    count = struct.unpack_from("<I", data, off)[0]
    off += 4
    out = []
    for _ in range(count):
        ln = struct.unpack_from("<I", data, off)[0]
        off += 4
        out.append(data[off:off + ln].rstrip(b"\0").decode("utf-8", "replace"))
        off += ln + 8 + 8 + 16 + 4  # offset, size, md5, flags
    return out


def main():
    fails, notes = [], []
    files = tracked_files()

    vendor = []
    for p in files:
        low = p.lower()
        if low.endswith(VENDOR_EXT):
            vendor.append(p)
        elif p.startswith(VENDOR_DIRS) and os.path.basename(p) not in ALLOWED_IN_VENDOR_DIRS:
            vendor.append(p)
    if vendor:
        fails.append({"check": "vendor_files_tracked", "files": vendor[:50]})

    secrets = []
    for p in files:
        if not p.lower().endswith(TEXT_EXT) or p == "tools/release_check.py":
            continue
        try:
            data = open(os.path.join(ROOT, p), "rb").read()
        except OSError:
            continue
        for name, rx in SECRET_PATTERNS.items():
            if rx.search(data):
                secrets.append({"file": p, "pattern": name})
    if secrets:
        fails.append({"check": "secrets_in_repo", "hits": secrets})

    presets = open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8").read()
    for block in re.split(r"\n(?=\[preset\.\d+\]\n)", presets):
        name = re.search(r'^name="([^"]*)"', block, re.M)
        excl = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
        if not name:
            continue
        have = [x.strip() for x in (excl.group(1) if excl else "").split(",")]
        missing = [m for m in MUST_EXCLUDE if m not in have]
        if missing:
            fails.append({"check": "export_exclude", "preset": name.group(1), "missing": missing})

    checksums = []
    builds = os.path.join(ROOT, "builds")
    if os.path.isdir(builds):
        for dp, _, fns in os.walk(builds):
            for fn in sorted(fns):
                if fn.endswith(".import"):
                    continue
                full = os.path.join(dp, fn)
                data = open(full, "rb").read()
                rel = os.path.relpath(full, ROOT)
                checksums.append("%s  %s" % (hashlib.sha256(data).hexdigest(), rel))
                if fn.endswith(".pck"):
                    paths = pck_paths(data)
                    if paths is None:
                        notes.append("%s: not a readable pack, file list not checked" % rel)
                    else:
                        bad = [x for x in paths if x.startswith(("references/", "res://references/", "docs/", "design/", "tests/", "scenes/tests/"))
                               or "/quarantine/" in x]
                        if bad:
                            fails.append({"check": "internal_files_in_build", "file": rel, "paths": bad[:20]})
                    for name, rx in SECRET_PATTERNS.items():
                        if rx.search(data):
                            fails.append({"check": "secret_in_build", "file": rel, "pattern": name})
        if checksums and "--checksums" in sys.argv:
            os.makedirs(os.path.join(ROOT, "evidence"), exist_ok=True)
            open(os.path.join(ROOT, "evidence", "build_checksums.txt"), "w").write("\n".join(sorted(checksums)) + "\n")
    else:
        notes.append("no builds/ folder: checksums and pack scan skipped (NOT_RUN)")

    version = re.search(r'config/version="([^"]*)"', open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read())
    report = {"ok": not fails, "version": version.group(1) if version else "", "tracked_files": len(files),
              "build_files_hashed": len(checksums), "failures": fails, "notes": notes}
    os.makedirs(os.path.join(ROOT, "evidence", "release"), exist_ok=True)
    json.dump(report, open(os.path.join(ROOT, "evidence", "release", "release_check.json"), "w"), indent=1)
    print("RELEASE_CHECK %s: %d tracked files, %d build files hashed, %d failures" % (
        "ok" if not fails else "FAIL", len(files), len(checksums), len(fails)))
    if not QUIET:
        for f in fails:
            print("  FAIL", json.dumps(f)[:300])
        for n in notes:
            print("  note", n)
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
