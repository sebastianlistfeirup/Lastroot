#!/usr/bin/env bash
# Renders the branding placeholders (icon PNGs, splash, store capsules) into
# assets/branding/. Own art only: procedural dioramas + DejaVu Sans wordmark.
# Usage: tools/synty/capture_branding.sh   (needs xvfb-run; python3+Pillow optional
# for squeezing splash.png under 1 MB)
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --rendering-method gl_compatibility \
	--resolution 640x360 --path . res://scenes/tests/branding_capture.tscn 2>&1 \
	| grep -E "branding:|ERROR" || echo "  (no branding output)"
S=assets/branding/splash.png
if [ -f "$S" ] && [ "$(stat -c %s "$S")" -gt 1000000 ] && command -v python3 >/dev/null; then
	python3 -I -c "
import sys
from PIL import Image
p = sys.argv[1]
Image.open(p).convert('RGB').quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(p, optimize=True)
" "$S" && echo "  splash quantized to $(stat -c %s "$S") bytes"
fi
