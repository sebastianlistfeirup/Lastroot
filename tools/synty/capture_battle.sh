#!/usr/bin/env bash
# Real battle-scene screenshots for the stage art gate (needs xvfb-run):
#   evidence/asset_pipeline/battle_{boss,mid}_1080p.png, battle_mid_portrait.png,
#   stage_mutations_{all,none}.png (TreeStage art gate with all / no mutations).
# Usage: tools/synty/capture_battle.sh
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
EV=evidence/asset_pipeline
run() {
	local res="$1"; shift
	timeout 240 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-method gl_compatibility --resolution "$res" "$@" 2>&1 \
		| grep -E "captured|SCRIPT ERROR|Parse Error" || echo "  (no capture line for $*)"
}
run 1920x1080 -- --setup=boss --capture=$EV/battle_boss_1080p.png --frames=90
run 1920x1080 -- --setup=midbattle --capture=$EV/battle_mid_1080p.png --frames=90
run 390x844 -- --setup=midbattle --capture=$EV/battle_mid_portrait.png --frames=90
run 1920x1080 res://scenes/tests/stage_mutations.tscn -- --capture=$EV/stage_mutations_all.png --frames=60
run 1920x1080 res://scenes/tests/stage_mutations.tscn -- --mutations= --capture=$EV/stage_mutations_none.png --frames=60
ls -la $EV/battle_*.png $EV/stage_mutations_*.png
