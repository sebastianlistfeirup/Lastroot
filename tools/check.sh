#!/usr/bin/env bash
# LASTROOT local gate (bible p.55 CI contract): catalog/plan validation ->
# Godot import -> parse check -> domain + forecast tests -> scene smoke.
# Usage: tools/check.sh   (GODOT_BIN overrides the binary)
set -u
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/.."
python3 tools/validate_catalog.py >/dev/null && python3 tools/validate_plan.py >/dev/null
V=$?
echo "validators_exit=$V"
python3 tools/release_check.py --quiet
R=$?
"$GODOT" --headless --path . --import --quit-after 2000 >/tmp/lr_import.log 2>&1
grep -E "SCRIPT ERROR|Parse Error" /tmp/lr_import.log | sort -u | head -20
C_OUT=$(timeout 120 "$GODOT" --headless --path . res://scenes/tests/compile_all.tscn 2>&1 | grep -E "^COMPILE")
echo "$C_OUT"
if ! echo "$C_OUT" | grep -q " 0 failed"; then
	echo "compile_exit=1"
	exit 1
fi
L=0
if [ -f tools/loc_extract.py ]; then python3 tools/loc_extract.py --check; L=$?; fi
T_OUT=$(timeout 600 "$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1)
T=$?
echo "$T_OUT" | grep -E "FAIL|SCRIPT ERROR|tests,"
if echo "$T_OUT" | grep -q "SCRIPT ERROR"; then T=1; fi
S_OUT=$(timeout 600 "$GODOT" --headless --path . res://scenes/tests/scene_smoke.tscn 2>&1)
S=$?
echo "$S_OUT" | grep -E "SMOKE|FAIL|SCRIPT ERROR" | head -60
if echo "$S_OUT" | grep -q "SCRIPT ERROR"; then S=1; fi
M=0
if [ -f scenes/tests/meta_smoke.tscn ]; then
	M_OUT=$(timeout 600 "$GODOT" --headless --path . res://scenes/tests/meta_smoke.tscn 2>&1)
	M=$?
	echo "$M_OUT" | grep -E "META_SMOKE|FAIL|SCRIPT ERROR" | head -60
	if echo "$M_OUT" | grep -q "SCRIPT ERROR"; then M=1; fi
fi
echo "validators_exit=$V release_exit=$R loc_exit=$L tests_exit=$T smoke_exit=$S meta_exit=$M"
exit $(( V | R | L | T | S | M ))
