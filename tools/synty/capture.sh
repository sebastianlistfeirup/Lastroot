#!/usr/bin/env bash
# Screenshots of the style gate and RigLab into evidence/asset_pipeline/ (needs xvfb-run).
# Usage: tools/synty/capture.sh [mode ...]   modes: lineup stage props gate riglab anim
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
MODES=("$@")
[ ${#MODES[@]} -eq 0 ] && MODES=(lineup gate stage props riglab anim)
run() {
	timeout 180 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --rendering-method gl_compatibility --resolution 1600x900 --path . "$@" 2>&1 \
		| grep -E "captured|SCRIPT ERROR|Parse Error" || echo "  (no capture line)"
}
for m in "${MODES[@]}"; do
	case "$m" in
		riglab) run res://scenes/tests/rig_lab.tscn -- --slot=unit.B01 --capture=evidence/asset_pipeline/riglab_B01.png
			run res://scenes/tests/rig_lab.tscn -- --slot=unit.B04 --capture=evidence/asset_pipeline/riglab_B04.png ;;
		anim) run res://scenes/tests/asset_gallery.tscn -- --mode=gate --state=attack --capture=evidence/asset_pipeline/gallery_gate_attack.png ;;
		*) run res://scenes/tests/asset_gallery.tscn -- --mode="$m" --capture="evidence/asset_pipeline/gallery_$m.png" ;;
	esac
done
