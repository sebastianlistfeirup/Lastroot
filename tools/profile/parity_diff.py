#!/usr/bin/env python3
"""Pixel diff of two screenshot folders (same file names), e.g. before/after the
draw-call work:  python3 -I tools/profile/parity_diff.py <before> <after> [--sheet=<dir>]

Per image: mean absolute difference (0-255), share of pixels differing by more
than 8 and by more than 32 levels (max channel), max difference. With --sheet
it writes before | after | diff (x4) JPGs (half size) into that folder."""
import json
import os
import sys

from PIL import Image, ImageChops


def stats(a: Image.Image, b: Image.Image) -> dict:
    d = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
    px = d.getdata()
    n = len(px)
    tot = 0
    over8 = 0
    over32 = 0
    mx = 0
    for r, g, bl in px:
        m = max(r, g, bl)
        tot += r + g + bl
        if m > 8:
            over8 += 1
        if m > 32:
            over32 += 1
        if m > mx:
            mx = m
    return {"mean_abs": round(tot / (3.0 * n), 3), "pct_over_8": round(100.0 * over8 / n, 3),
            "pct_over_32": round(100.0 * over32 / n, 3), "max": mx}, d


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sheet = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--sheet=")), "")
    before, after = args[0], args[1]
    out = {}
    for name in sorted(os.listdir(before)):
        if not name.endswith(".png") or not os.path.exists(os.path.join(after, name)):
            continue
        a = Image.open(os.path.join(before, name))
        b = Image.open(os.path.join(after, name))
        if a.size != b.size:
            out[name] = {"error": "size %s vs %s" % (a.size, b.size)}
            continue
        s, d = stats(a, b)
        out[name] = s
        print("%-24s mean=%6.3f  >8: %6.3f%%  >32: %6.3f%%  max=%d" % (name, s["mean_abs"], s["pct_over_8"], s["pct_over_32"], s["max"]))
        if sheet:
            os.makedirs(sheet, exist_ok=True)
            w, h = a.size
            amp = d.point(lambda v: min(255, v * 4))
            sh = Image.new("RGB", (w * 3, h))
            sh.paste(a.convert("RGB"), (0, 0))
            sh.paste(b.convert("RGB"), (w, 0))
            sh.paste(amp, (2 * w, 0))
            sh = sh.resize((w * 3 // 2, h // 2), Image.LANCZOS)
            sh.save(os.path.join(sheet, name.replace(".png", "_before_after_diff.jpg")), quality=72)
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
