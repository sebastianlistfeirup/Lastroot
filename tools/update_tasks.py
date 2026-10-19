#!/usr/bin/env python3
"""Sets plan/tasks.json statuses from evidence/<task>/result.json:
PASS -> DONE (only when all dependencies are DONE), VERIFYING stays VERIFYING,
FAIL -> REWORK. Tasks implemented ahead of their phase gate get IN_PROGRESS
with a note (the phase gate rule forbids DONE before earlier phases are DONE).
Usage: python3 tools/update_tasks.py <commit>"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
commit = sys.argv[1] if len(sys.argv) > 1 else None
path = os.path.join(ROOT, "plan", "tasks.json")
d = json.load(open(path, encoding="utf-8"))
OWNER = "claude-code (ferie-session 19.10.2026)"

AHEAD = {
    "LR-14": "Implementeret før porten: alle 24 korttyper i reduceren, B05 målvalg/fallback, upgrade-matrix pr. instans (CardStats). test_cards.gd har en test pr. kort + relikvie-/championkombinationer. Mangler: fase 1-port.",
    "LR-15": "Implementeret før porten: R01-R08, M01-M04 og fire championretninger med to trin; turflags, M02 afledt, M04 én gang, retning låses. Tests i test_cards/test_run. Mangler: før/efter-visning poleres i UI og fase 1-port.",
    "LR-16": "Implementeret før porten: fem forgreningspunkter, fast rewardrækkefølge, stabile slot-id'er med offered/claimed/skipped, lejr/møde/fjernelse/kortknude, min. 7 normale kort, udbud gemt før visning. Rute- og belønningsskærme: se run_screen.",
    "LR-17": "Implementeret før porten: kamp 2-5 og Askekronen (ankring, tur-10-eskalation, nederlag ved Kronen, nederlagsprioritet). Bot gennemfører alle seks kampe med begge champions (evidence/balance).",
    "LR-18": "Grundlag: event-presenter med timere, skip/0.5/1/2x, UnitAnimator-kontrakt med proceduremæssige proxyanimationer. Mangler godkendte Synty/PolyPerfect/Mixamo-klip.",
    "LR-19": "120 gemte prognosescenarier matcher state-hash og eventrækkefølge (test_forecast). Web-eksportpreset (single-thread, Compatibility) findes. Mangler: fysisk telefon/iPad-test.",
    "LR-21": "Grundlag: continue/ny run, save efter hver kommando, presentation checkpoint. Afbrydelser ved alle skærmskift testes i meta_smoke.",
    "LR-22": "Grundlag: TreeStage med tre etager i REF_05-stemning (rødder/stamme/krone), stammevarianter, alle fire mutationer synlige uden for spilområdet, tomgangsglød. Proxies; Synty-træ mangler.",
    "LR-24": "Grundlag: kortportrætter renderet fra visual slots (skifter automatisk til Synty), emblemer for besværgelser, fraktionsrammer, glyf+tal for statusser, galleri over alle 24 kort + upgrades (evidence/meta_screens/cards_*.png).",
    "LR-25": "Grundlag: rutekort (REF_04) med kommende bølger og bossregler, lejr med før/efter og pris, championskærm med begge retninger/låst retning, relikvie-/mutationsvalg. meta_smoke dækker alle knuder.",
    "LR-26": "Grundlag: boss-intro (kan springes over), bossbanner fra kampstart, boss-advarsler i prognosen, 36 placeholder-lydcues + musik, resultatskærm med træets opsummering.",
    "LR-28": "Grundlag: tekststørrelse, reduceret bevægelse, animationshastighed, en/da, glyf+tal for alle statusser, 48 px-mål, tastatur/gamepad i kampen, portrætlayout-prototype. Mangler fysisk telefon/iPad-test.",
    "LR-29": "Grundlag: prognose p95 1,6 ms (evidence/perf), savefuzz og trunkering afvises, korrupt->backup, fremtidig version bevares. Mangler fps-måling på referencehardware.",
    "LR-27": "Grundlag: tools/balance/run_balance.gd (faste seeds, begge champions). Bot vinder 40/40 (D24) — menneskelig spiltest før talændringer.",
}

by_id = {t["id"]: t for t in d["tasks"]}
changed = True
while changed:  # dependencies may become DONE in the same pass
    changed = False
    for t in d["tasks"]:
        ev = os.path.join(ROOT, "evidence", t["id"], "result.json")
        if not os.path.exists(ev):
            continue
        r = json.load(open(ev, encoding="utf-8"))
        rel = "evidence/%s/result.json" % t["id"]
        deps_done = all(by_id[x]["status"] == "DONE" for x in t["depends_on"])
        new = t["status"]
        if r.get("status") == "PASS" and deps_done:
            new = "DONE"
        elif r.get("status") == "PASS":
            new = "VERIFYING"
        elif r.get("status") == "VERIFYING":
            new = "VERIFYING"
        elif r.get("status") == "FAIL":
            new = "REWORK"
        if new != t["status"] or rel not in t.get("evidence", []):
            t["status"] = new
            t["owner"] = OWNER
            if commit:
                t["last_commit"] = commit
            if rel not in t.get("evidence", []):
                t.setdefault("evidence", []).append(rel)
            if r.get("open"):
                t["notes"] = "Åbent: " + " ".join(r["open"])
            changed = True
for tid, note in AHEAD.items():
    t = by_id[tid]
    if t["status"] in ("TODO", "READY", "IN_PROGRESS"):
        t["status"] = "IN_PROGRESS"
        t["owner"] = OWNER
        t["notes"] = note
        if commit:
            t["last_commit"] = commit
json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
open(path, "a").write("\n")
counts = {}
for t in d["tasks"]:
    counts[t["status"]] = counts.get(t["status"], 0) + 1
print(counts)
