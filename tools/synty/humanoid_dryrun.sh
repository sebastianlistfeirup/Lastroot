#!/usr/bin/env bash
# HUMANOID dry run of the whole asset pipeline, the way the owner will use it, on generated
# licence-free rigs (tools/synty/make_humanoid_pack.py, needs Blender's Python):
#   Synty-named A-pose FBX + glTF, Mixamo-named T-pose FBX + glTF, a flat folder of Mixamo-style
#   clip FBX files WITHOUT skin -> unpack.py -> match.py -> build.sh (bone map, silhouette fix,
#   re-import passes) -> humanoid_check.gd in a running tree -> optional screenshots -> verdict.
# Writes evidence/asset_pipeline/humanoid_dryrun.json (+ _runtime.json, _build_report.json);
# removes everything else it created (packs, art/, synty_choices.json, slot_scenes.json).
# Usage: BPY_PYTHON=/path/to/python-with-bpy tools/synty/humanoid_dryrun.sh [--capture]
#        (or BLENDER=/path/to/blender). Refuses to run when data/art/synty_choices.json exists
#        (your real import): it would overwrite your choices.
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
EV=evidence/asset_pipeline
CAPTURE=0
[ "${1:-}" = "--capture" ] && CAPTURE=1
PACKS=(CC0Test_Synty CC0Test_Characters Mixamo)
if [ -e data/art/synty_choices.json ] || [ -e data/art/slot_scenes.json ] || [ -d art ]; then
	echo "NOT_RUN: data/art/synty_choices.json, slot_scenes.json or art/ exists (a real import?). Move them away first." >&2
	exit 2
fi
TMP=$(mktemp -d)
cleanup() {
	for p in "${PACKS[@]}"; do rm -rf "assets/quarantine/$p" "assets/imported/$p"; done
	rm -rf art data/art/synty_choices.json data/art/slot_scenes.json "$EV/build_report.json" "$TMP"
}
[ "${KEEP:-0}" = "1" ] || trap cleanup EXIT
if [ -n "${BPY_PYTHON:-}" ]; then
	"$BPY_PYTHON" tools/synty/make_humanoid_pack.py "$TMP/packs" | tail -1
elif command -v "${BLENDER:-blender}" >/dev/null 2>&1; then
	"${BLENDER:-blender}" -b --python tools/synty/make_humanoid_pack.py -- "$TMP/packs" 2>&1 | tail -1
else
	echo '{"status": "NOT_RUN", "reason": "no Blender / bpy (set BPY_PYTHON or BLENDER)"}' > "$EV/humanoid_dryrun.json"
	echo "NOT_RUN: set BPY_PYTHON (python with pip install bpy) or BLENDER"; exit 2
fi
python3 tools/synty/unpack.py "$TMP/packs/CC0Test_Synty"
python3 tools/synty/unpack.py "$TMP/packs/CC0Test_Characters"
python3 tools/synty/unpack.py "$TMP/packs/Mixamo"                    # flat folder of downloads (docs/HOMECOMING.md §3)
python3 tools/synty/match.py --packs "${PACKS[@]}" | tail -5
# The Mixamo-style character has no slot-like name: choose it by hand (as the owner would).
python3 - <<'PY'
import json
p = "data/art/synty_choices.json"
d = json.load(open(p))
d["choices"]["enemy.E03"] = {"source": "CC0Test_Characters/Ch_TestBot.fbx", "status": "manual", "rotation_y": 180}
d["choices"]["enemy.E05"] = {"source": "CC0Test_Characters/Ch_TestBot.glb", "status": "manual", "rotation_y": 180}
json.dump(d, open(p, "w"), indent=1)
PY
cp data/art/synty_choices.json "$TMP/choices.json"
tools/synty/build.sh -- --report=res://$EV/humanoid_dryrun_build_report.json | grep -E "^--- pass|wrappers:|FAIL|library|unit\.|enemy\." || true
"$GODOT" --headless --path . --script res://tools/synty/humanoid_check.gd -- --out=res://$EV/humanoid_dryrun_runtime.json 2>&1 \
	| grep -E "humanoid runtime|SCRIPT ERROR|couldn't resolve" | sort | uniq -c || true
if [ $CAPTURE -eq 1 ] && command -v xvfb-run >/dev/null 2>&1; then
	shot() {
		local res="$1"; shift
		timeout 240 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-method gl_compatibility --resolution "$res" "$@" 2>&1 | grep -E "^captured|^CAPTURE" || true
	}
	shot 1600x900 res://scenes/tests/rig_lab.tscn -- --slot=unit.B03 --capture=$EV/humanoid_riglab_B03.png
	shot 1600x900 res://scenes/tests/rig_lab.tscn -- --slot=enemy.E03 --capture=$EV/humanoid_riglab_E03.png
	shot 1600x900 res://scenes/tests/asset_gallery.tscn -- --mode=gate --state=attack --capture=$EV/humanoid_gate_attack.png
	shot 1280x720 -- --setup=midbattle --faction=SPORE --capture=$EV/humanoid_battle_mid.png --frames=90
fi
GODOT_VERSION=$("$GODOT" --version 2>/dev/null | head -1)
python3 - "$EV" "$GODOT_VERSION" "$TMP/choices.json" <<'PY'
import json, os, sys, time
ev, gv, chp = sys.argv[1:4]
def load(p):
    try:
        return json.load(open(p))
    except Exception as e:
        return {"_error": str(e)}
rep = load(os.path.join(ev, "humanoid_dryrun_build_report.json"))
rt = load(os.path.join(ev, "humanoid_dryrun_runtime.json"))
ch = load(chp)
slots = {s["slot"]: s for s in rep.get("slots", [])}
lib = next((a for a in rep.get("animations", []) if a.get("set") == "humanoid"), {})
clips = lib.get("clips", {})
R = rt.get("slots", {})
cross = rt.get("max_pose_difference_between_rigs_deg", {})
def pose(slot, state, bone):
    return R.get(slot, {}).get("poses", {}).get(state, {}).get(bone, [0, 0, 0])
rigs = ("unit.B03", "unit.S01", "enemy.E03", "enemy.E05")
checks = [
    ("match: flat Mixamo download folder recognised as clips (7 states)", len(ch.get("animations", {}).get("humanoid", {}).get("states", {})) == 7),
    ("match: idle=Breathing Idle, cast=Standing 1H Magic Attack 01 (no 'stand' mix-up)",
        ch.get("animations", {}).get("humanoid", {}).get("states", {}).get("idle", "").endswith("Breathing Idle.fbx")
        and ch.get("animations", {}).get("humanoid", {}).get("states", {}).get("cast", "").endswith("Standing 1H Magic Attack 01.fbx")),
    ("match: Synty-named FBX -> B03, glTF -> S01", ch.get("choices", {}).get("unit.B03", {}).get("status") == "auto" and ch.get("choices", {}).get("unit.S01", {}).get("status") == "auto"),
    ("build: 4 humanoid wrappers, nothing failed, no re-import pending", rep.get("failed", 1) == 0 and rep.get("built", 0) == 4 and not rep.get("reimport_needed", True)),
    ("build: every wrapper on GeneralSkeleton with the shared library", all(str(slots.get(s, {}).get("rig", "")).endswith("GeneralSkeleton") and slots[s].get("library", "").endswith("humanoid.res") for s in rigs)),
    ("build: 7 clips, all retargeted, only bone tracks", len(clips) == 7 and all(c.get("retargeted") for c in clips.values())
        and all(R.get(s, {}).get("non_bone_tracks", 1) == 0 for s in rigs)),
    ("build: Punching 1 m / Walking 1.2 m root travel removed", abs(clips.get("attack", {}).get("removed_travel_m", 0) - 1.0) < 0.05
        and abs(clips.get("move", {}).get("removed_travel_m", 0) - 1.2) < 0.05),
    ("fit: height = slot height, feet on y=0, footprint sane (skinned bounds)", all(abs(slots.get(s, {}).get("size_m", [0, 0])[1] - R.get(s, {}).get("height_m", -1)) < 0.05
        and abs(R.get(s, {}).get("feet_y", 9)) < 0.03 and not slots.get(s, {}).get("warnings") for s in rigs)),
    ("facing -Z on all four rigs", all(R.get(s, {}).get("facing") == "-Z" for s in rigs)),
    ("idle: arms hang down on every rig (Synty A-pose too)", all(pose(s, "idle", b)[1] < -0.8 for s in rigs for b in ("LeftUpperArm", "RightUpperArm"))),
    ("victory: arms up on every rig", all(pose(s, "victory", b)[1] > 0.7 for s in rigs for b in ("LeftUpperArm", "RightUpperArm"))),
    ("attack: punching arm points forward (-Z) at contact", all(pose(s, "attack", "RightUpperArm")[2] < -0.8 or pose(s, "attack", "LeftUpperArm")[2] < -0.8 for s in rigs)),
    ("same clip -> same pose on Synty A-pose and Mixamo T-pose rigs (< 8 deg)", bool(cross) and max(cross.values()) < 8.0),
    ("move: legs swing, hips stay in place", all(R.get(s, {}).get("move_thigh_swing_deg", 0) > 25 and R.get(s, {}).get("move_hips_drift_m", 9) < 0.05 for s in rigs)),
    ("UnitAnimator plays the clip: contact + finished", all(R.get(s, {}).get("unit_animator_uses_clip") and R.get(s, {}).get("attack_contact")
        and 0 < R.get(s, {}).get("attack_finished_s", -1) < 3 for s in rigs)),
]
out = {"status": "PASS" if all(v for _k, v in checks) else "FAIL", "date": time.strftime("%Y-%m-%d %H:%M:%S"), "godot": gv,
       "source": "Generated by tools/synty/make_humanoid_pack.py (Blender/bpy): our own boxes-on-bones rigs, no third-party files.",
       "rigs": {"unit.B03": "Synty-named, A-pose, FBX (Z-up armature node)", "unit.S01": "Synty-named, A-pose, glTF",
                "enemy.E03": "mixamorig:* names, T-pose, FBX", "enemy.E05": "mixamorig:* names, T-pose, glTF"},
       "clips": "7 Mixamo-named FBX clip files without skin, flat folder, authored on the T-pose Mixamo rig",
       "checks": [{"check": k, "result": "PASS" if v else "FAIL"} for k, v in checks],
       "max_pose_difference_between_rigs_deg": cross,
       "build_report": "humanoid_dryrun_build_report.json", "runtime": "humanoid_dryrun_runtime.json"}
json.dump(out, open(os.path.join(ev, "humanoid_dryrun.json"), "w"), indent=1)
for k, v in checks:
    print(("PASS " if v else "FAIL ") + k)
print("humanoid dry run:", out["status"])
sys.exit(0 if out["status"] == "PASS" else 1)
PY
