#!/usr/bin/env bash
# Purchased packs -> LASTROOT wrappers in one go (after unpack.py and match.py):
#   stage chosen files -> Godot import -> build (bone maps / atlas set in import
#   settings) -> import again -> build again (up to 3 passes) -> report.
# Usage: tools/synty/build.sh [--choices data/art/synty_choices.json]
# Extra args after "--" go to build_wrappers.gd (e.g. -- --prefabs=res://art/prefabs/).
# Exit: 0 built · 2 missing input (no godot / no synty_choices.json; clear message) ·
#       3 nothing to build (no auto/approved choice) · 1 a wrapper failed.
set -euo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
STAGE_ARGS=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do STAGE_ARGS+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
BUILD_ARGS=("$@")
if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "FEJL: Godot findes ikke som '$GODOT'. Installér Godot 4.7.1 eller sæt GODOT_BIN=/sti/til/godot." >&2
	echo "ERROR: Godot binary '$GODOT' not found (set GODOT_BIN)." >&2
	exit 2
fi
set +e
python3 tools/synty/stage.py "${STAGE_ARGS[@]}"
RC=$?
set -e
if [ $RC -eq 3 ]; then
	echo "Intet at bygge: ingen godkendte/auto-valg i synty_choices.json. Spillet bruger stadig proxies (intet er ændret)."
	echo "Nothing to build: no auto/approved choices. Game still uses proxies (nothing changed)."
	exit 3
elif [ $RC -ne 0 ]; then
	echo "build.sh stoppet før import (se beskeden ovenfor). / stopped before import (see message above)." >&2
	exit $RC
fi
for pass in 1 2 3; do
	"$GODOT" --headless --path . --import --quit-after 3000 >/dev/null 2>&1 || true
	OUT=$("$GODOT" --headless --path . --script res://tools/synty/build_wrappers.gd -- "${BUILD_ARGS[@]}" 2>&1 \
		| grep -vE "^Godot Engine|^$|autoload|settings_service|audio_service|save_service|game_session|resource_loader.cpp|gdscript.cpp:1120|^   at:" || true)
	echo "--- pass $pass"
	echo "$OUT"
	grep -q "import settings updated" <<< "$OUT" || break
done
echo "Report: evidence/asset_pipeline/build_report.json · check figures in scenes/tests/rig_lab.tscn and the style gate scenes/tests/asset_gallery.tscn"
