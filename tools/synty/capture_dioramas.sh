#!/usr/bin/env bash
# Captures the meta-screen dioramas at 1920x1080 and 430x932 into evidence/asset_pipeline/.
# Usage: tools/synty/capture_dioramas.sh   (needs xvfb-run)
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
EV=evidence/asset_pipeline
run() {
	local res="$1"; shift
	timeout 200 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --rendering-method gl_compatibility --resolution "$res" --path . "$@" 2>&1 \
		| grep -E "captured|SCRIPT ERROR" || echo "  (no capture for $*)"
}
run 1920x1080 res://scenes/art/route_diorama.tscn -- --progress=3 --capture=$EV/diorama_route_1080p.png --frames=60
run 430x932 res://scenes/art/route_diorama.tscn -- --portrait --progress=3 --capture=$EV/diorama_route_portrait.png --frames=60
run 1920x1080 res://scenes/art/menu_diorama.tscn -- --champion=BARK --capture=$EV/diorama_menu_1080p.png --frames=60
run 430x932 res://scenes/art/menu_diorama.tscn -- --portrait --champion=SPORE --capture=$EV/diorama_menu_portrait.png --frames=60
