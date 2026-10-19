#!/usr/bin/env bash
# Records RigLab cycling every state for a few slots with Godot's Movie Maker
# (fixed 30 fps, so tweens run in real time) and joins them into one small mp4.
# Usage: tools/synty/record_riglab.sh [out.mp4] [slot ...]   (needs xvfb-run + ffmpeg)
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
OUT="${1:-evidence/asset_pipeline/riglab_states.mp4}"
shift || true
SLOTS=("$@")
[ ${#SLOTS[@]} -eq 0 ] && SLOTS=(unit.B01 unit.S01 enemy.E06)
TMP=$(mktemp -d)
LIST="$TMP/list.txt"
for s in "${SLOTS[@]}"; do
	timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-method gl_compatibility --resolution 960x540 \
		--path . --write-movie "$TMP/$s.avi" --fixed-fps 30 --quit-after 330 res://scenes/tests/rig_lab.tscn -- --slot="$s" >/dev/null 2>&1
	if [ -f "$TMP/$s.avi" ]; then
		ffmpeg -loglevel error -y -i "$TMP/$s.avi" -vf "scale=800:-2,fps=24" -c:v libx264 -preset veryfast -crf 31 -pix_fmt yuv420p "$TMP/$s.mp4"
		echo "file '$TMP/$s.mp4'" >> "$LIST"
	else
		echo "no movie for $s"
	fi
done
ffmpeg -loglevel error -y -f concat -safe 0 -i "$LIST" -c copy "$OUT"
ls -la "$OUT"
rm -rf "$TMP"
