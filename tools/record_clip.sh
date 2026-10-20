#!/usr/bin/env bash
# Records one real-gameplay clip with Godot's Movie Maker (LR-34).
# The game is driven by AutoDriver through GameSession (scenes/tests/record_clip.tscn);
# nothing is generated or edited except trimming and H.264 encoding.
# Usage: tools/record_clip.sh <name> [WxH] -- <game user args...>
#   tools/record_clip.sh forecast_turn 1280x720 -- --setup=battle1 --faction=SPORE --seed=3 --max_seconds=28
# Output: evidence/video/<name>.mp4 + evidence/video/<name>.json (run log).
# Env: GODOT_BIN, CRF (default 30), FPS (default 30), TRIM_START (seconds, default 0).
set -eu
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/.."
NAME="$1"; shift
SIZE="1280x720"
if [ "${1:-}" != "--" ] && [ -n "${1:-}" ]; then SIZE="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
FPS="${FPS:-30}"
CRF="${CRF:-30}"
TRIM_START="${TRIM_START:-0}"
W="${SIZE%x*}"; H="${SIZE#*x}"
TMP="$(mktemp -d)"
mkdir -p evidence/video
timeout 1800 xvfb-run -a -s "-screen 0 ${W}x${H}x24" "$GODOT" --path . --rendering-method gl_compatibility \
	--resolution "$SIZE" --write-movie "$TMP/$NAME.avi" --fixed-fps "$FPS" \
	res://scenes/tests/record_clip.tscn -- --log="evidence/video/$NAME.json" "$@" 2>&1 \
	| grep -E "CLIP_LOG|SCRIPT ERROR|ERROR" | head -20 || true
ffmpeg -loglevel error -y -ss "$TRIM_START" -i "$TMP/$NAME.avi" -an -c:v libx264 -preset slow -crf "$CRF" \
	-pix_fmt yuv420p -movflags +faststart "evidence/video/$NAME.mp4"
rm -rf "$TMP"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "evidence/video/$NAME.mp4")
echo "CLIP evidence/video/$NAME.mp4 ${DUR}s $(du -k "evidence/video/$NAME.mp4" | cut -f1) KB"
