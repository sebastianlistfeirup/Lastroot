#!/usr/bin/env bash
# Parses every GDScript of the visual asset layer and prints only real problems
# (missing autoload files of other areas are filtered out).
# Usage: tools/synty/check_scripts.sh   (exit 1 if any script fails to parse)
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
FAIL=0
for f in scripts/runtime/visual/*.gd tools/synty/*.gd addons/lastroot_slots/*.gd tests/unit/test_visual_slots.gd; do
	[ -f "$f" ] || continue
	OUT=$("$GODOT" --headless --path . --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR|WARNING" -A1 \
		| grep -vE "autoload|settings_service|audio_service|save_service|game_session|resource_loader.cpp|gdscript.cpp:1120|^--$|optimized_translation" || true)
	if [ -n "$OUT" ]; then
		echo "== $f"
		echo "$OUT"
		grep -qE "SCRIPT ERROR|Parse Error|ERROR" <<< "$OUT" && FAIL=1
	fi
done
[ $FAIL -eq 0 ] && echo "check_scripts: all visual-layer scripts parse" || echo "check_scripts: FAILED"
exit $FAIL
