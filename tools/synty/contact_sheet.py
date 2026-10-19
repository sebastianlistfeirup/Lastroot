#!/usr/bin/env python3
"""Contact sheets for tools/capture_all.sh (needs Pillow).

  contact_sheet.py build   <raw dir> <out dir> <title>
      Every PNG under <raw dir>/<group>/... is downscaled to max 1280 px wide and
      written to <out dir>/<group>/ as JPEG (q 84), or as an optimized PNG when it
      has real transparency. Writes manifest.json and index.html (grouped by area,
      relative paths, click an image for its full file).
  contact_sheet.py compare <before dir> <after dir>
      Writes <after dir>/compare_<before name>.html: before | after per item,
      matched by group + file stem; items present on only one side are listed too.
  contact_sheet.py tile    <dir> <out.png> <name> ...
      Tiles <dir>/<name>.png into a labelled 3-column sheet (RigLab states sheet).
"""
import html
import json
import os
import sys

from PIL import Image, ImageDraw

MAX_W = 1280
GROUP_ORDER = ["battle", "battle_ui", "heart", "dioramas", "gallery", "riglab", "meta", "cards", "branding"]
GROUP_TITLE = {
    "battle": "Battle stage (TreeStage + units)",
    "battle_ui": "Battle interaction states",
    "heart": "Heart health strip",
    "dioramas": "Meta-screen dioramas (menu / route / epilog)",
    "gallery": "Asset gallery (style gate)",
    "riglab": "RigLab figures + states sheet",
    "meta": "Meta screens",
    "cards": "Card gallery",
    "branding": "Branding (icon, splash, store placeholders)",
}
CSS = """
:root{--bg:#0d1019;--panel:#161b28;--text:#e9eef7;--dim:#9aa6bd;--accent:#3ff2d6}
@media (prefers-color-scheme: light){:root:not([data-theme=dark]){--bg:#f3f5f9;--panel:#fff;--text:#18202e;--dim:#556074;--accent:#0f8f80}}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.45 system-ui,sans-serif}
header{padding:20px 16px 8px;max-width:1500px;margin:auto}
h1{margin:0 0 4px;font-size:24px} h2{margin:28px 0 10px;font-size:18px;color:var(--accent)}
p.meta{margin:0;color:var(--dim)} main{padding:0 16px 40px;max-width:1500px;margin:auto}
nav a{color:var(--dim);margin-right:12px;font-size:14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px}
figure{margin:0;background:var(--panel);border-radius:8px;padding:8px;overflow:hidden}
figure img{width:100%;height:auto;display:block;border-radius:4px;background:repeating-conic-gradient(#8884 0 25%,#0000 0 50%) 0 0/16px 16px}
figcaption{font-size:13px;color:var(--dim);margin-top:6px;word-break:break-all}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px;background:var(--panel);border-radius:8px;padding:8px;margin-bottom:12px}
.pair h3{grid-column:1/-1;margin:0;font-size:14px}.pair .side{font-size:12px;color:var(--dim)}
.pair img{width:100%;height:auto;display:block;border-radius:4px}
.missing{display:flex;align-items:center;justify-content:center;min-height:120px;border:1px dashed var(--dim);border-radius:4px;color:var(--dim)}
@media (max-width:640px){.pair{grid-template-columns:1fr}}
"""


def _page(title, sub, body):
    return ("<!doctype html><html lang=en><head><meta charset=utf-8>"
            "<meta name=viewport content='width=device-width,initial-scale=1'>"
            f"<title>{html.escape(title)}</title><style>{CSS}</style></head><body>"
            f"<header><h1>{html.escape(title)}</h1><p class=meta>{sub}</p></header><main>{body}</main></body></html>")


def _order(groups):
    return sorted(groups, key=lambda g: (GROUP_ORDER.index(g) if g in GROUP_ORDER else 99, g))


def build(raw, out, title):
    os.makedirs(out, exist_ok=True)
    items = []
    for dirpath, _dirs, files in os.walk(raw):
        rel = os.path.relpath(dirpath, raw)
        if rel == ".":
            continue
        group = rel.split(os.sep)[0]
        sub = rel.split(os.sep)[1:]
        for f in sorted(files):
            if not f.lower().endswith(".png") or f.startswith("."):
                continue
            src = os.path.join(dirpath, f)
            try:
                im = Image.open(src)
                im.load()
            except Exception as e:  # noqa: BLE001 - a broken shot must not stop the sheet
                print("skip", src, e)
                continue
            w, h = im.size
            stem = "_".join(sub + [os.path.splitext(f)[0]])
            if w > MAX_W:
                im = im.resize((MAX_W, max(1, round(h * MAX_W / w))), Image.LANCZOS)
            alpha = im.mode in ("RGBA", "LA") and im.getchannel("A").getextrema()[0] < 250
            os.makedirs(os.path.join(out, group), exist_ok=True)
            if alpha:
                name = stem + ".png"
                im.save(os.path.join(out, group, name), optimize=True)
            else:
                name = stem + ".jpg"
                im.convert("RGB").save(os.path.join(out, group, name), quality=84, optimize=True, progressive=True)
            items.append({"group": group, "stem": stem, "file": f"{group}/{name}", "source_size": [w, h]})
    items.sort(key=lambda i: (GROUP_ORDER.index(i["group"]) if i["group"] in GROUP_ORDER else 99, i["stem"]))
    with open(os.path.join(out, "manifest.json"), "w") as fh:
        json.dump({"title": title, "items": items}, fh, indent=1)
    groups = _order({i["group"] for i in items})
    body = "<nav>" + "".join(f"<a href='#{g}'>{g}</a>" for g in groups) + "</nav>"
    for g in groups:
        body += f"<h2 id='{g}'>{html.escape(GROUP_TITLE.get(g, g))}</h2><div class=grid>"
        for i in (x for x in items if x["group"] == g):
            w, h = i["source_size"]
            body += (f"<figure><a href='{i['file']}'><img loading=lazy src='{i['file']}' alt='{html.escape(i['stem'])}'></a>"
                     f"<figcaption>{html.escape(i['stem'])} &middot; {w}x{h}</figcaption></figure>")
        body += "</div>"
    total = sum(os.path.getsize(os.path.join(out, i["file"])) for i in items)
    sub = f"{len(items)} images in {len(groups)} areas &middot; {total / 1e6:.1f} MB &middot; downscaled to max {MAX_W} px wide"
    with open(os.path.join(out, "index.html"), "w") as fh:
        fh.write(_page(f"LASTROOT captures: {title}", sub, body))
    print(f"contact sheet: {out}/index.html ({len(items)} images, {total / 1e6:.1f} MB)")


def compare(before, after):
    def load(d):
        with open(os.path.join(d, "manifest.json")) as fh:
            return {(i["group"], i["stem"]): i for i in json.load(fh)["items"]}
    a, b = load(before), load(after)
    bname, aname = os.path.basename(os.path.normpath(before)), os.path.basename(os.path.normpath(after))
    keys = sorted(set(a) | set(b), key=lambda k: (GROUP_ORDER.index(k[0]) if k[0] in GROUP_ORDER else 99, k[1]))
    rel = os.path.relpath(before, after)
    body, cur = "", None
    for k in keys:
        if k[0] != cur:
            cur = k[0]
            body += f"<h2 id='{cur}'>{html.escape(GROUP_TITLE.get(cur, cur))}</h2>"

        def cell(item, prefix, label):
            if not item:
                return f"<div><div class=side>{label}</div><div class=missing>not captured</div></div>"
            src = f"{prefix}/{item['file']}" if prefix else item["file"]
            return f"<div><div class=side>{label}</div><a href='{src}'><img loading=lazy src='{src}'></a></div>"
        body += (f"<div class=pair><h3>{html.escape(k[1])}</h3>"
                 f"{cell(a.get(k), rel, 'before: ' + html.escape(bname))}{cell(b.get(k), '', 'after: ' + html.escape(aname))}</div>")
    out = os.path.join(after, f"compare_{bname}.html")
    with open(out, "w") as fh:
        fh.write(_page(f"LASTROOT before / after: {bname} → {aname}",
                       f"{len(keys)} items &middot; <a href='index.html'>this run</a>", body))
    print("compare:", out)


def tile(d, out, names):
    tiles = []
    for n in names:
        p = os.path.join(d, n + ".png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGB")
            # the gate lineup sits in the middle band; drop the empty sky and floor
            tiles.append((n, im.crop((0, round(im.height * 0.12), im.width, round(im.height * 0.8)))))
    if not tiles:
        print("tile: no images in", d)
        return
    tw = 640
    th = round(tiles[0][1].height * tw / tiles[0][1].width)
    cols = 3
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows * th), (11, 14, 26))
    draw = ImageDraw.Draw(sheet)
    for idx, (n, im) in enumerate(tiles):
        x, y = (idx % cols) * tw, (idx // cols) * th
        sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, y))
        draw.rectangle([x, y, x + 12 + 9 * len(n), y + 22], fill=(0, 0, 0))
        draw.text((x + 6, y + 5), n, fill=(63, 242, 214))
    sheet.save(out)
    print("tile:", out, sheet.size)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "build" and len(sys.argv) == 5:
        build(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "compare" and len(sys.argv) == 4:
        compare(sys.argv[2], sys.argv[3])
    elif cmd == "tile" and len(sys.argv) >= 5:
        tile(sys.argv[2], sys.argv[3], sys.argv[4:])
    else:
        print(__doc__)
        sys.exit(2)
