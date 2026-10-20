#!/usr/bin/env bash
# LR-22: the real battle screen with all 16 tree-mutation combinations, to check
# that three floors, numbers, targets and the forecast stay readable.
# Writes evidence/mutations/combo_<ids>.jpg + contact_sheet.jpg (needs xvfb-run, Pillow).
# Usage: tools/capture_mutation_combos.sh [SETUP] [FACTION]
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-godot}"
SETUP="${1:-midbattle}"
FACTION="${2:-BARK}"
OUT=evidence/mutations
mkdir -p "$OUT"
ALL=(M01 M02 M03 M04)
for mask in $(seq 0 15); do
	ids=()
	for i in 0 1 2 3; do
		if (( (mask >> i) & 1 )); then ids+=("${ALL[$i]}"); fi
	done
	list=$(IFS=,; echo "${ids[*]}")
	name=${list:-none}
	timeout 120 xvfb-run -a "$GODOT" --path . --rendering-method gl_compatibility --resolution 1280x720 -- \
		--setup="$SETUP" --faction="$FACTION" --mutations="$list" --capture="/tmp/lr_mut_${name//,/_}.png" --frames=60 >/dev/null 2>&1
done
python3 - "$OUT" <<'PY'
import glob, os, sys
from PIL import Image, ImageDraw
out = sys.argv[1]
shots = sorted(glob.glob("/tmp/lr_mut_*.png"), key=lambda p: (p.count("M"), p))
tiles = []
for p in shots:
    name = os.path.basename(p)[7:-4]
    im = Image.open(p).convert("RGB")
    im.save(os.path.join(out, "combo_%s.jpg" % name), quality=82)
    t = im.resize((640, 360))
    ImageDraw.Draw(t).rectangle([0, 0, 200, 26], fill=(0, 0, 0))
    ImageDraw.Draw(t).text((6, 6), name.replace("_", "+"), fill=(255, 255, 255))
    tiles.append(t)
cols = 4
sheet = Image.new("RGB", (640 * cols, 360 * ((len(tiles) + cols - 1) // cols)), (20, 20, 20))
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % cols) * 640, (i // cols) * 360))
sheet.save(os.path.join(out, "contact_sheet.jpg"), quality=80)
print("MUTATION_COMBOS", len(tiles), "captures ->", out)
PY
rm -f /tmp/lr_mut_*.png
