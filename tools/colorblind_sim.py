#!/usr/bin/env python3
"""LR-24: simulate protanopia, deuteranopia and tritanopia (Machado et al. 2009,
severity 1.0, applied in linear RGB) on real captures, so a reviewer can check
that no information is carried by colour alone.
Usage: python3 tools/colorblind_sim.py <out_dir> <image> [<image> ...]
Writes <name>_<type>.jpg and <name>_strip.jpg (original + three simulations)."""
import os, sys
from PIL import Image

M = {
    "protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
    "deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
    "tritan": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}
TO_LIN = [((i / 255.0) / 12.92 if i / 255.0 <= 0.04045 else (((i / 255.0) + 0.055) / 1.055) ** 2.4) for i in range(256)]


def to_srgb(v):
    v = min(1.0, max(0.0, v))
    return int(round(255 * (12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055)))


LUT = [to_srgb(i / 4095.0) for i in range(4096)]


def simulate(im, m):
    px = im.load()
    out = Image.new("RGB", im.size)
    po = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y][:3]
            lr, lg, lb = TO_LIN[r], TO_LIN[g], TO_LIN[b]
            c = [m[i][0] * lr + m[i][1] * lg + m[i][2] * lb for i in range(3)]
            po[x, y] = tuple(LUT[int(min(1.0, max(0.0, v)) * 4095)] for v in c)
    return out


def main():
    out_dir, paths = sys.argv[1], sys.argv[2:]
    os.makedirs(out_dir, exist_ok=True)
    for p in paths:
        im = Image.open(p).convert("RGB")
        if im.width > 1280:
            im = im.resize((1280, int(im.height * 1280 / im.width)))
        name = os.path.splitext(os.path.basename(p))[0]
        sims = [im] + [simulate(im, M[k]) for k in ("protan", "deutan", "tritan")]
        for k, s in zip(("protan", "deutan", "tritan"), sims[1:]):
            s.save(os.path.join(out_dir, "%s_%s.jpg" % (name, k)), quality=82)
        w, h = im.width // 2, im.height // 2
        strip = Image.new("RGB", (w * 2, h * 2))
        for i, s in enumerate(sims):
            strip.paste(s.resize((w, h)), ((i % 2) * w, (i // 2) * h))
        strip.save(os.path.join(out_dir, "%s_strip.jpg" % name), quality=82)
        print("COLORBLIND", name, "->", out_dir)


if __name__ == "__main__":
    main()
