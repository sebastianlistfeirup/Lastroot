# STATUS

| Felt | Værdi |
|---|---|
| project | LASTROOT |
| spec_version | Udviklingsbibel v2.0 (19.10.2026) |
| game_status | GREYBOX_PLAYABLE (hele runnet spilbart med proxies) |
| engine_version | Godot 4.7.1-stable (official, a13da4feb) — opgraderet fra 4.5.1 22.10 (D35) |
| profile | HOLIDAY (cloud-container, headless + Xvfb; ingen Synty/PolyPerfect-filer, ingen Windows-maskine, ingen fysisk telefon) |
| current_phase | 1 · Fundament (port ikke erklæret bestået) |
| last_passed_gate | — (fase 1-porten kræver LR-08/09/11/12 DONE, som kræver menneske/rigtige assets/Windows) |
| active_task | LR-08..LR-12 VERIFYING · fase 2-arbejde bygget før porten (IN_PROGRESS) |
| last_commit | se `git log -1` |
| next_command | `tools/check.sh` og derefter `godot --path .` |
| web playtest | Artifact "Lastroot Playtest": https://claude.ai/artifact/BsnV9QwztLZ5haFiHhnAjX (privat, greybox) |

## Tests kørt (faktiske resultater)

| Lag | Kommando | Resultat |
|---|---|---|
| Validatorer | `python3 tools/validate_catalog.py`, `validate_plan.py` | valid |
| Parse | `godot --headless --path . res://scenes/tests/compile_all.tscn` | 0 fejl → `evidence/compile_report.json` |
| Domæne + prognose + kort + saves + meta + visuals | `godot --headless --path . --script res://tests/run_tests.gd` | **146 tests, 0 fejl** → `evidence/test_report.json` |
| Prognosescenarier | 120 gemte (`fixtures/forecast/scenarios.json`) | state-hash og eventrækkefølge matcher rigtig afvikling |
| Kampscene (rigtigt input) | `godot --headless --path . res://scenes/tests/scene_smoke.tscn` | **47 checks, 0 fejl** (inkl. tastatur, gamepad, tekststørrelse, saves) → `evidence/scene_smoke.json` |
| Meta-skærme (rigtige knapper) | `godot --headless --path . res://scenes/tests/meta_smoke.tscn` | **635 checks, 0 fejl** (inkl. genoptag, tastatur/pad, onboarding, lyd, playtest-log, demo, telefon-kamp) → `evidence/meta_smoke.json` |
| Web på telefon (rigtig touch) | `node tools/web_phone_flow.js` (Playwright, Chromium) | **12 trin bestået** → `evidence/web_phone_flow/` |
| Layout (alle skærme) | `godot --headless --path . res://scenes/tests/layout_smoke.tscn` (i check.sh) | **220 skærme, 0 fejl** (720p, 1080p, telefon, tablet; tekst 100/130 %, engelsk) → `evidence/layout/layout_report.json` |
| Release-hygiejne | `python3 tools/release_check.py` (i check.sh) | ok → `evidence/release/release_check.json` |
| Oversættelse | `python3 tools/loc_extract.py --check` | 423 nøgler, 0 mangler |
| Grafikpipeline | `tools/synty/selftest.sh` | 22/22 (falske pakker) → `evidence/asset_pipeline/selftest.json` |
| Balance (bot) | `tools/balance/run_balance.gd -- --seeds=20` | BARK 20/20, SPORE 20/20 sejre, ~10 hjerteliv tabt → `evidence/balance/` |
| Eksport | Linux + Windows + Web | Linux-build kørt under Xvfb (boss-screenshot). Windows NOT_RUN på Windows. Web kørt i headless Chromium (swiftshader, ~2 fps = softwarerendering, ikke en telefonmåling). |
| Video | Movie Maker + autoplay | `evidence/video/battle1_spore_autoplay.mp4` (kamp 1, 25 s) |
| FBX-prøveimport | assimp BSD-testfiler (ikke humanoid) gennem hele kæden | wrapper bygget, klip afspillet → `fbx_dryrun.json`. **Humanoid (21.10):** egne Synty- og Mixamo-navngivne rigs (FBX+glTF, A-/T-pose) + Mixamo-klip gennem hele kæden 15/15 efter seks rettede fejl (skala ×614, retarget A/T-pose, holdte knogler, Armature-spor, tom take, flad Mixamo-mappe); krydstjek med ægte Mixamo-eksport → `evidence/asset_pipeline/humanoid_dryrun.json`. Købte pakker stadig uafprøvet |
| Prognose-latens | `tools/balance/profile_forecast.gd` | p95 1,6 ms (mål < 50 ms) → `evidence/perf/forecast_latency.json` |
| Capture-sæt | `tools/capture_all.sh` | proxy-baseline (126 billeder) i `evidence/captures/proxies_baseline/` |
| Menneskelig gennemspilning | — | NOT_RUN |
| Fysisk telefon/iPad | — | NOT_RUN (kun browser-emulering) |

## Opgaver (`plan/tasks.json`)

- **DONE** (beviser i `evidence/LR-xx/result.json`): LR-01, LR-02, LR-03, LR-04, LR-05, LR-06, LR-07.
- **VERIFYING**: LR-08 (visuel kontrol på rigtig skærm), LR-09 (menneskelig gennemspilning med hver champion), LR-10 (automatik PASS; venter på LR-08/09), LR-11 (rigtig Synty/PolyPerfect-importprøve), LR-12 (Windows-build på referencemaskinen + fase 1-tag).
- **IN_PROGRESS — bygget før porten**: LR-14, LR-15, LR-16, LR-17, LR-18, LR-19, LR-21, LR-27 (se `notes`).
- **TODO**: resten af fase 2-4.

## Næste tre opgaver

1. LR-09/LR-12: spil kamp 1 med begge champions på din maskine; kør Windows-buildet. Agent markerer derefter LR-08..LR-12 og fase 1-porten.
2. LR-11/LR-13: `tools/synty/build.sh` med de købte pakker; godkend line-up i `scenes/tests/asset_gallery.tscn`.
3. LR-27: menneskelig spiltest af sværhedsgrad (botten vinder for let, D24) før talændringer.

## Også bygget (ud over fase 1)

Hele løbet (6 kampe, rute, lejr/møde/fjernelse/kortknude, belønninger, championretninger, relikvier, mutationer), "Sådan spiller du" + førstegangsguide, tastatur/gamepad, 3D-dioramaer bag menu/rute/resultat, kortportrætter fra visual slots, målringe og fare-ringe, hjertets skadestilstande, udtryksfulde proxy-animationer, lyd v2 (procedural, egen), lokal spiltest-log med svarformular og eksport, demo-tilstand (2 kampe, preset "Web Demo"), app-ikon og splash, telefonlayout med prognose-ark og tommelfinger-knaprække.

## Nyt 22.10: alle assets valgt

- **`data/art/synty_selection.json` = bindende valg for alle 51 slots** ud fra de 16 ejede SyntyPass-arkiver (Realmrends ledger, sha256). Fordeling: 7 ejede og verificeret i Realmrend, 16 ejede efter mønster, 2 `needs_download` (B04 PolyPerfect, B06 Fantasy Rivals — begge med automatisk reserve/proxy), 26 proxy (etager, stamme, hjerte, M01/M02/M04, 18 FX). Ét fælles humanoid-klipsæt fra de ejede Synty ANIMATION-pakker.
- `tools/synty/apply_selection.py` (selection → `synty_choices.json`, `--dry-run`, `--check`, `--archives`), `stage.py` bruger pakkens rigtige atlas, `focus.py` virker på valgte slots, `tools/synty/fix_vendor_uid_collision.py` (port af Realmrends UID-fix), `doctor.py` tjekker valget. Test: `tools/synty/test_selection_tools.py` 23/23 (i `tools/check.sh`).
- `docs/REALMREND_LESSONS.md` (alt lært med de rigtige pakker), download-tjekliste i `docs/HOMECOMING.md` §2. **SyntyPass udløber ca. 16.11.2026.**
- Ikke bevist: ingen købt fil er åbnet her; DF-/Dungeon-figurnavne og ANIMATION-mapper er mønstre (butikslister/konvention).

## Nyt 21.10 (anden ferierunde)

- **Færre draw calls:** statiske proxy-dele bages sammen ved bygning (`ProxyMerge`): midtkamp 1238→388, boss 1732→522, fuldt træ 2722→1016 (−63–70 %), dioramaer −70–83 %; visuelt identisk (pixel-diff i `evidence/perf/drawcalls/`). Nødbremse: `ProxyMerge.enabled = false`.
- Rettet: kortbilleder forsvandt i hånden efter layout-rettelsen (billedet blev krympet ved første måling og voksede aldrig tilbage); nu reversibelt + scene_smoke-tjek.
- **Spillet er kun på engelsk (D34):** ingen sprogvælger; danske oversættelser er hvilende i CSV/katalog. Dokumenter forbliver danske.

- **Sværhedsgrad "Svær"** i Indstillinger (D32): fjender/boss 130 % HP for nye løb — afprøv balanceforslaget direkte.
- Danske afvisningsbeskeder med tal/etagenavne (`Loc.reason`); etageknapper var engelske.
- Test af alle 31 kort×opgradering og bossens immunitet mod flyt/fjern.
- `tools/release_check.py` i check.sh (ingen købte filer/hemmeligheder i git, interne mapper ude af builds); fandt og fjernede testscener fra eksporten; build-checksums.
- `docs/ASSET_MAP.md` (hver slot → Synty/PolyPerfect/Mixamo-kandidat) og `docs/HOMECOMING.md` (tjekliste til første session hjemme); `tools/synty/doctor.py` og `focus.py`.
- Gem-skema 2 med migrering af ægte v1-saves (`fixtures/legacy/`), id-/typevalidering, tmp-gendannelse, karantæne af beskadigede filer, egen demo-gemmeplads (D33); dobbelt-belønning umulig efter reload.
- Layout-smoke over 330 skærmkombinationer i check.sh; klipningsfejl rettet i menu, guide, credits, indstillinger, resultat, rute, kort og mærker.
- Profilering: `evidence/perf/stress_profile.json` (softwarerendering, ikke spillerhardware), `leak_check.json` (noder og objekter stabile; lækket ved at forlade kampen midt i afspilning er rettet; statisk hukommelse stiger ~36 KB pr. kamp — **årsag fundet: Godot 4.5.1 efterlader 48 B pr. oprettet Control** (minimal repro `tools/profile/control_growth.tscn`), ubetydeligt for spillere, se `analysis_21_10`).
- Demo-optagelser (prognose, etagekamp, mutation, boss, demo-slut) i `evidence/video/`; butikstekst verificeret punkt for punkt; "Linux Demo"-preset; gamepad i kamp testet (simuleret).
- Nightcap/Sporekolos bruger nærkampsangreb i stedet for magi-klip.
- Mutationskombinationer (16), farveblindhedssimulering, lyd→visuelt-audit, valgrapport for balance-bot (`--meta=seeded`).

## Kendte begrænsninger

- Alle figurer/miljø er proxies; ingen rigtige animationsklip.
- Portrætlayout er gennemarbejdet, men kun testet i browser-emulering (ikke fysisk telefon). + -pladser kan ligge tæt ved fulde etager.
- Afvisningsårsager med tal/etagenavn oversættes via `Loc.reason` (skabelonmatch); en helt ny reducer-tekst uden CSV-nøgle vises på engelsk (loc_extract fanger almindelige `return "..."`).
