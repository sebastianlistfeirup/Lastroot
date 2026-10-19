#!/usr/bin/env bash
# End-to-end test of the LASTROOT asset pipeline with FAKE packs (no purchased files):
# make_test_pack (Synty .unitypackage, PolyPerfect .zip, Mixamo folder) -> unpack ->
# match -> stage -> import/build passes -> runtime checks in a running tree -> verdict.
# Writes evidence/asset_pipeline/selftest.json with the real results and removes
# everything else it created. Usage: tools/synty/selftest.sh   (exit 0 = all PASS)
set -uo pipefail
GODOT="${GODOT_BIN:-godot}"
cd "$(dirname "$0")/../.."
EV=evidence/asset_pipeline
mkdir -p "$EV"
TMP=$(mktemp -d)
PACKS=(SelfTestSynty SelfTestPolyPerfect SelfTestMixamo)
CHOICES=assets/imported/_selftest_choices.json
SCENES=res://assets/imported/_selftest_slot_scenes.json
cleanup() {
	for p in "${PACKS[@]}"; do rm -rf "assets/quarantine/$p" "assets/imported/$p"; done
	rm -rf "$CHOICES" assets/imported/_selftest_slot_scenes.json art/prefabs/_selftest art/animations/_selftest "$TMP"
	rm -f art/rigs/SelfTest* art/materials/self_test* 2>/dev/null
	rmdir art/prefabs art/animations art/rigs art/materials art 2>/dev/null || true
}
[ "${KEEP:-0}" = "1" ] || trap cleanup EXIT
if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo '{"status": "NOT_RUN", "reason": "godot binary not found"}' > "$EV/selftest.json"
	echo "NOT_RUN: godot not found"; exit 2
fi
python3 tools/synty/make_test_pack.py "$TMP" >/dev/null
python3 tools/synty/unpack.py "$TMP/SelfTestSynty.unitypackage" --pack SelfTestSynty
python3 tools/synty/unpack.py "$TMP/SelfTestPolyPerfect.zip" --pack SelfTestPolyPerfect
python3 tools/synty/unpack.py "$TMP/SelfTestMixamo" --pack SelfTestMixamo
python3 tools/synty/match.py --packs "${PACKS[@]}" --out "$CHOICES" | tail -12
tools/synty/build.sh --choices "$CHOICES" -- --choices=res://$CHOICES --prefabs=res://art/prefabs/_selftest \
	--slot-scenes=$SCENES --anim-dir=res://art/animations/_selftest --report=res://$EV/selftest_build_report.json \
	| grep -E "^--- pass|wrappers:|FAIL|library|unit\.|enemy\.|stage\.|prop\." || true
"$GODOT" --headless --path . --script res://tools/synty/selftest_check.gd -- --slot-scenes=$SCENES --out=res://$EV/selftest_runtime.json 2>&1 \
	| grep -E "selftest runtime|SCRIPT ERROR" || true
GODOT_VERSION=$("$GODOT" --version 2>/dev/null | head -1)
python3 - "$EV" "$GODOT_VERSION" "$CHOICES" <<'PY'
import json, os, sys, time
ev, gv, choices = sys.argv[1], sys.argv[2], sys.argv[3]
def load(p):
    try:
        return json.load(open(p))
    except Exception as e:
        return {"_error": str(e)}
rep = load(os.path.join(ev, "selftest_build_report.json"))
rt = load(os.path.join(ev, "selftest_runtime.json"))
ch = load(choices)
slots = {s["slot"]: s for s in rep.get("slots", [])}
lib = next((a for a in rep.get("animations", []) if a.get("set") == "humanoid" and a.get("ok")), {})
clips = lib.get("clips", {})
def near(a, b, tol):
    try:
        return abs(float(a) - float(b)) <= tol
    except Exception:
        return False
g = lambda k: slots.get(k, {})
checks = [
    ("unpack: Unity-only files skipped, models kept", all(os.path.exists("assets/quarantine/%s/manifest.json" % p) for p in ("SelfTestSynty", "SelfTestPolyPerfect", "SelfTestMixamo"))
        and load("assets/quarantine/SelfTestSynty/manifest.json").get("skipped_unity_files", 0) >= 6),
    ("match: floor, props, trunk, golem->B01, deer->B04 proposed", all(ch.get("choices", {}).get(s, {}).get("status") == "auto" for s in
        ("stage.floor_roots", "prop.lantern", "prop.crystal", "prop.rock", "stage.trunk", "unit.B01", "unit.B04"))),
    ("match: Mixamo clips -> humanoid idle/attack/hit/death", set(ch.get("animations", {}).get("humanoid", {}).get("states", {})) >= {"idle", "attack", "hit", "death"}),
    ("build: every chosen slot built, nothing failed", rep.get("failed", 1) == 0 and rep.get("built", 0) >= 7 and not rep.get("reimport_needed", True)),
    ("floor: centimetres fitted to 11.6 m, top at y=0", near(g("stage.floor_roots").get("size_m", [0])[0], 11.6, 0.02)
        and near(g("stage.floor_roots").get("min_m", [0, 9])[1] + g("stage.floor_roots").get("size_m", [0, 0])[1], 0.0, 0.01)),
    ("crystal: cm -> m (x0.01), ~1 m tall", near(g("prop.crystal").get("scale", 0), 0.01, 1e-6) and near(g("prop.crystal").get("size_m", [0, 0])[1], 1.0, 0.02)),
    ("lantern: off-centre pivot re-centred, feet on y=0", near(g("prop.lantern").get("min_m", [9])[0], -0.15, 0.01) and near(g("prop.lantern").get("min_m", [0, 9])[1], 0.0, 0.01)),
    ("trunk: scaled to the 4.5 m segment", near(g("stage.trunk").get("size_m", [0, 0])[1], 4.5, 0.02)),
    ("atlas material applied to every static model", all(g(s).get("uses_atlas") for s in ("stage.floor_roots", "prop.lantern", "prop.crystal", "prop.rock", "stage.trunk"))),
    ("golem: humanoid bone map (GeneralSkeleton), height fitted to 2.6 m", str(g("unit.B01").get("rig", "")).endswith("GeneralSkeleton") and near(g("unit.B01").get("height_m", 0), 2.6, 0.03)),
    ("golem: imported facing +Z, wrapper faces -Z", g("unit.B01").get("facing") == "-Z" and rt.get("b01_facing") == "-Z"),
    ("humanoid library: 4 clips, all retargeted", len(clips) == 4 and all(c.get("retargeted") for c in clips.values())),
    ("Punching made in-place (1 m root travel removed)", near(clips.get("attack", {}).get("removed_travel_m", 0), 1.0, 0.05)
        and near(rt.get("b01_attack_hips_travel_m", 9), 0.0, 0.01)),
    ("runtime: B01 is the model, not the proxy", rt.get("b01_is_model") is True and rt.get("b01_has_unit_animator") is True),
    ("runtime: Mixamo attack clip rotates the Synty rig's arm", float(rt.get("b01_attack_rotates_arm_deg", 0)) > 10.0),
    ("runtime: has_clip attack/idle true, victory false (reported missing)", rt.get("b01_has_clip_attack") is True and rt.get("b01_has_clip_idle") is True
        and rt.get("b01_missing_victory") is True and "victory" in rt.get("b01_reported_missing", [])),
    ("runtime: finished arrives for clip (attack) + contact frame", 0 < float(rt.get("b01_finished_attack_s", -1)) < 3.0 and rt.get("b01_contact_fired") is True),
    ("runtime: finished arrives for a MISSING clip (victory fallback)", 0 < float(rt.get("b01_finished_victory_fallback_s", -1)) < 3.0),
    ("deer: quadruped keeps own clips, no humanoid retarget", rt.get("b04_is_model") is True and rt.get("b04_no_humanoid_retarget") is True
        and rt.get("b04_has_clip_attack") is True and rt.get("b04_has_clip_move") is True and rt.get("b04_missing_hit") is True),
    ("deer: faces -Z, missing hit still finishes", rt.get("b04_facing") == "-Z" and 0 < float(rt.get("b04_finished_hit_fallback_s", -1)) < 3.0),
    ("runtime: floor model 11.6 m wide, top at y=0", rt.get("floor_is_model") is True and near(rt.get("floor_width_m", 0), 11.6, 0.03) and near(rt.get("floor_top_y", 9), 0.0, 0.02)),
    ("runtime: unmapped slot stays proxy; unknown id never null", rt.get("s02_still_proxy") is True and rt.get("unknown_not_null") is True),
]
out = {"status": "PASS" if all(v for _k, v in checks) else "FAIL", "date": time.strftime("%Y-%m-%d %H:%M:%S"), "godot": gv,
       "note": "Fake packs from tools/synty/make_test_pack.py (glTF models; FBX goes through the same Godot importer interface but is not exercised here).",
       "checks": [{"check": k, "result": "PASS" if v else "FAIL"} for k, v in checks],
       "build_report": "selftest_build_report.json", "runtime": rt}
json.dump(out, open(os.path.join(ev, "selftest.json"), "w"), indent=1)
for k, v in checks:
    print(("PASS " if v else "FAIL ") + k)
print("selftest:", out["status"])
sys.exit(0 if out["status"] == "PASS" else 1)
PY
