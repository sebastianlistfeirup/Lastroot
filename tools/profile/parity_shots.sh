#!/usr/bin/env bash
# Visual A/B shots for the draw-call work (fixed fps, so tweens are deterministic):
#   tools/profile/parity_shots.sh <out dir> [project dir] [extra godot user args, e.g. --no-merge]
# Writes midbattle / boss / full_tree battle shots, the asset gallery line-up and
# stage, and the menu diorama as PNG into <out dir>. Compare two dirs with
#   python3 -I tools/profile/parity_diff.py <before dir> <after dir>
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
OUT="$(realpath -m "$1")"; PROJ="${2:-$(dirname "$0")/../..}"; shift; [ $# -gt 0 ] && shift
EXTRA=("$@")
mkdir -p "$OUT"
run() {   # run <resolution> <args...>
	local res="$1"; shift
	timeout 300 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path "$PROJ" --fixed-fps 60 \
		--rendering-method gl_compatibility --resolution "$res" "$@" 2>&1 | grep -E "PARITY|SCRIPT ERROR" || true
}
for st in midbattle boss full_tree; do
	run 1920x1080 res://tools/profile/parity_capture.tscn -- --state=$st --out="$OUT/battle_$st.png" "${EXTRA[@]}"
done
for m in lineup stage; do
	run 1600x900 res://scenes/tests/asset_gallery.tscn -- --mode=$m --capture="$OUT/gallery_$m.png" "${EXTRA[@]}"
done
# DioramaCapture saves relative to the project: capture into a scratch folder there.
TMP="$PROJ/.parity_tmp"; mkdir -p "$TMP" && touch "$TMP/.gdignore"
run 1920x1080 res://scenes/art/menu_diorama.tscn -- --champion=BARK --capture=res://.parity_tmp/menu_1080p.png --frames=60 "${EXTRA[@]}"
run 1920x1080 res://scenes/art/route_diorama.tscn -- --progress=3 --capture=res://.parity_tmp/route_1080p.png --frames=60 "${EXTRA[@]}"
run 1920x1080 res://scenes/art/epilog_diorama.tscn -- --result=won --faction=BARK --path=BULWARK --mutations=M01,M02,M03,M04 --capture=res://.parity_tmp/epilog_won.png --frames=70 "${EXTRA[@]}"
mv "$TMP"/*.png "$OUT"/ 2>/dev/null; rm -rf "$TMP"
ls "$OUT"
