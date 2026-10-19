#!/usr/bin/env python3
"""Builds evidence/<task-id>/result.json from the real reports written by the
test runs (evidence/test_report.json, scene_smoke.json, meta_smoke.json,
compile_report.json, balance, asset pipeline selftest, screenshots).
A task is PASS only when every mapped check exists and passed; anything that
needs a human, real assets or another machine is listed under `open` and the
status becomes VERIFYING instead of PASS. Unmapped tasks are NOT_RUN.
Usage: python3 tools/write_evidence.py [commit]"""
import json, os, subprocess, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EV = os.path.join(ROOT, "evidence")
commit = sys.argv[1] if len(sys.argv) > 1 else subprocess.run(
    ["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()


def load(p):
    try:
        return json.load(open(os.path.join(EV, p), encoding="utf-8"))
    except Exception:
        return None


unit = load("test_report.json") or {}
smoke = load("scene_smoke.json") or {}
meta = load("meta_smoke.json") or {}
comp = load("compile_report.json") or {}
bal = load("balance/balance_report_greedy.json")
selftest = load("asset_pipeline/selftest.json")
names = set(unit.get("names", []))
ufail = unit.get("failures", [])
smoke_res = {r["name"]: r["ok"] for r in smoke.get("results", [])}
meta_res = {r["name"]: r["ok"] for r in meta.get("results", [])} if isinstance(meta.get("results"), list) else {}


def unit_check(prefixes):
    hit = [n for n in names if any(n.startswith(p) for p in prefixes)]
    bad = [f for f in ufail if any(f.startswith(p) for p in prefixes)]
    return {"kind": "unit", "match": prefixes, "found": len(hit), "failures": bad, "ok": len(hit) > 0 and not bad}


def smoke_check(keys, src=smoke_res, label="scene_smoke"):
    missing = [k for k in keys if k not in src]
    bad = [k for k in keys if k in src and not src[k]]
    return {"kind": label, "match": keys, "missing": missing, "failures": bad, "ok": not missing and not bad}


def file_check(paths):
    missing = [p for p in paths if not os.path.exists(os.path.join(ROOT, p))]
    return {"kind": "files", "match": paths, "missing": missing, "ok": not missing}


T = {
    "LR-01": dict(checks=lambda: [file_check(["docs/VERSION_MATRIX.md", "docs/CAPABILITY_MATRIX.md", "project.godot", "tools/check.sh"]),
                                  {"kind": "compile", "ok": comp.get("status") == "PASS", "scripts": comp.get("scripts")},
                                  smoke_check(["menu_to_battle_to_result_to_menu"]), {"kind": "meta_smoke", "ok": meta.get("status") == "PASS", "checks": meta.get("checks")}],
                  expected="Ren opstart og lukning uden parserfejl. VERSION_MATRIX og baselinecommit findes. menu->battle->result->menu.",
                  cmd="tools/check.sh"),
    "LR-02": dict(checks=lambda: [unit_check(["test_catalog/", "test_rng/"])],
                  expected="24 unikke typer, 22+2. Begge startdecks 12 instanser. Dublet-ID og ukendt effekt afvises med præcis årsag.",
                  cmd="godot --headless --path . --script res://tests/run_tests.gd"),
    "LR-03": dict(checks=lambda: [unit_check(["test_battle_matrix/test_t03", "test_battle_matrix/test_t10", "test_battle_matrix/test_deterministic", "test_battle_matrix/test_boss", "test_battle_matrix/test_heart"])],
                  expected="Overlevende fjende rykker højst én etage og kæmper én gang. Tomt bræt før sidste bølge er ikke sejr. Samme input samme resultat.",
                  cmd="godot --headless --path . --script res://tests/run_tests.gd"),
    "LR-04": dict(checks=lambda: [unit_check(["test_battle_matrix/test_t01", "test_battle_matrix/test_t02", "test_battle_matrix/test_t05", "test_battle_matrix/test_new_poison", "test_battle_matrix/test_growth", "test_cards/test_s06"])],
                  expected="T01/T02/T05 består. Død behandles én gang, Torne rekursiverer ikke, ny Gift tickes ikke to gange.",
                  cmd="godot --headless --path . --script res://tests/run_tests.gd"),
    "LR-05": dict(checks=lambda: [unit_check(["test_battle_matrix/test_t09", "test_battle_matrix/test_card_in_exactly", "test_battle_matrix/test_invalid_target", "test_battle_matrix/test_full_floor", "test_cards/test_b01", "test_cards/test_s01", "test_cards/test_b02", "test_cards/test_b07", "test_cards/test_b08", "test_cards/test_s02", "test_cards/test_s07"]),
                                  smoke_check(["BARK wins battle 1 through the scene (phase reward)", "SPORE wins battle 1 through the scene (phase reward)"])],
                  expected="Begge champions kan spille første kamp. Ugyldigt mål bruger intet. Kort i præcis én zone; døde væsner kommer ikke tilbage.",
                  cmd="tests + scene smoke"),
    "LR-06": dict(checks=lambda: [unit_check(["test_forecast/", "test_battle_matrix/test_t07"])],
                  expected="Mindst 20 fixtures matcher state og eventrækkefølge. Preview bruger ingen kraft, RNG eller relikvieflag.",
                  cmd="godot --headless --path . --script res://tests/run_tests.gd"),
    "LR-07": dict(checks=lambda: [smoke_check(["champion shows insert slots", "slot sets a pending command", "preview forecast rendered", "second confirm does nothing (one tap, one action)", "invalid command shows a reason", "invalid command changes nothing", "input locked while resolving", "no command accepted while locked", "resize keeps BattleState"]),
                                  file_check(["evidence/shots/battle_mid_1080p.png", "evidence/shots/battle_mid_portrait.png"])],
                  expected="Ét klik/tap giver højst én handling. Ingen nødvendig hover. UI viser årsag til ugyldigt mål. Resize nulstiller ikke BattleState.",
                  cmd="godot --headless --path . res://scenes/tests/scene_smoke.tscn"),
    "LR-08": dict(checks=lambda: [smoke_check(["three floor views", "unlocked after playback", "no view for a dead unit", "2x playback and skip end in identical view state", "presentation checkpoint cleared"]),
                                  file_check(["evidence/shots/battle_mid_1080p.png"])],
                  expected="Alle tre etager synlige. Skip og 2x giver samme state som normal afvikling. Ingen præsentationscallback ændrer skade eller reward.",
                  cmd="godot --headless --path . res://scenes/tests/scene_smoke.tscn",
                  open_items=["Visuel kontrol på rigtig skærm (headless/Xvfb er ikke visuel godkendelse)."]),
    "LR-09": dict(checks=lambda: [smoke_check(["BARK wins battle 1 through the scene (phase reward)", "SPORE wins battle 1 through the scene (phase reward)", "BARK end banner shown", "SPORE end banner shown"]),
                                  unit_check(["test_battle_matrix/test_t10"])],
                  expected="Første kamp kan gennemføres med begge champions uden debug. Ingen tidlig sejr, dobbelt opstigning eller uvarslet bølge.",
                  cmd="scene smoke (bot sender de samme kommandoer som UI'et)",
                  open_items=["Én menneskelig gennemspilning af kamp 1 med hver champion (onboarding-hints vurderes)."]),
    "LR-10": dict(checks=lambda: [unit_check(["test_save/"]),
                                  smoke_check(["corrupt save offers the backup", "backup holds the previous good save", "future version refused", "future-version file is not deleted", "JSON export/import", "saved with presentation_pending during playback", "load shows the finished result, nothing re-settled"])],
                  expected="Load reroller ikke hånd og afregner ikke events igen. Korrupt save tilbyder backup. Fremtidig version afvises uden at slette original.",
                  cmd="tests + scene smoke"),
    "LR-11": dict(checks=lambda: [{"kind": "asset_selftest", "ok": bool(selftest) and selftest.get("status") == "PASS"},
                                  file_check(["docs/ASSET_LEDGER.csv", "docs/ANIMATION_LEDGER.csv"])],
                  expected="Importprøve har beviser hvis assets findes. Første kamp/save virker stadig. Manglende assets stopper ikke domænearbejdet.",
                  cmd="tools/synty/selftest.sh",
                  open_items=["Ingen købte Synty/PolyPerfect-filer i containeren: rigtig importprøve (én træ-/klippeprøve + én rigget figur) udestår.", "Visuel godkendelse forbliver åben."]),
    "LR-12": dict(checks=lambda: [file_check(["evidence/build_checksums.txt", "evidence/shots/linux_build_boss.png"]),
                                  {"kind": "unit", "ok": unit.get("status") == "PASS"}, {"kind": "scene_smoke", "ok": smoke.get("status") == "PASS"}],
                  expected="Gate 1 bestået med faktisk kørbar kamp og korrekt prognose/save. Ingen P0/P1. Headless alene tæller ikke som visuelt kontrolleret demo.",
                  cmd="godot --headless --path . --export-release Linux/Windows; Linux-build kørt under Xvfb",
                  open_items=["Windows-build køres på referencemaskinen.", "Video af første kamp fra ren profil.", "LR-11 visuel/import-del."]),
}

now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
summary = {}
for tid, spec in T.items():
    checks = spec["checks"]()
    all_ok = all(c["ok"] for c in checks)
    open_items = spec.get("open_items", [])
    status = "FAIL" if not all_ok else ("VERIFYING" if open_items else "PASS")
    res = {
        "task_id": tid, "commit": commit, "engine_version": unit.get("engine_version"),
        "command": spec["cmd"], "exit_code": 0 if all_ok else 1, "expected": spec["expected"],
        "observed": checks, "open": open_items, "fixture": "fixtures/forecast/scenarios.json" if tid in ("LR-06",) else None,
        "timestamp": now, "status": status,
        "artifacts": [a for a in ["evidence/test_report.json", "evidence/scene_smoke.json", "evidence/compile_report.json"] if os.path.exists(os.path.join(ROOT, a))],
    }
    os.makedirs(os.path.join(EV, tid), exist_ok=True)
    json.dump(res, open(os.path.join(EV, tid, "result.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    summary[tid] = status
print(json.dumps(summary, indent=1))
