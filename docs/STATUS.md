# STATUS

| Felt | Værdi |
|---|---|
| project | LASTROOT |
| spec_version | Udviklingsbibel v2.0 (19.10.2026) |
| game_status | GREYBOX_PLAYABLE (hele runnet spilbart med proxies) |
| engine_version | Godot 4.5.1-stable (official, f62fdbde1) |
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
| Domæne + prognose + kort + saves + meta + visuals | `godot --headless --path . --script res://tests/run_tests.gd` | **115 tests, 0 fejl** → `evidence/test_report.json` |
| Prognosescenarier | 120 gemte (`fixtures/forecast/scenarios.json`) | state-hash og eventrækkefølge matcher rigtig afvikling |
| Kampscene (rigtigt input) | `godot --headless --path . res://scenes/tests/scene_smoke.tscn` | **40 checks, 0 fejl** (inkl. tastatur, tekststørrelse, saves) → `evidence/scene_smoke.json` |
| Meta-skærme (rigtige knapper) | `godot --headless --path . res://scenes/tests/meta_smoke.tscn` | **455 checks, 0 fejl** (inkl. genoptag, tastatur/pad, onboarding) → `evidence/meta_smoke.json` |
| Oversættelse | `python3 tools/loc_extract.py --check` | 350 nøgler, 0 mangler |
| Grafikpipeline | `tools/synty/selftest.sh` | 22/22 (falske pakker) → `evidence/asset_pipeline/selftest.json` |
| Balance (bot) | `tools/balance/run_balance.gd -- --seeds=20` | BARK 20/20, SPORE 20/20 sejre, ~10 hjerteliv tabt → `evidence/balance/` |
| Eksport | Linux + Windows + Web | Linux-build kørt under Xvfb (boss-screenshot). Windows NOT_RUN på Windows. Web kørt i headless Chromium (swiftshader, ~2 fps = softwarerendering, ikke en telefonmåling). |
| Video | Movie Maker + autoplay | `evidence/video/battle1_spore_autoplay.mp4` (kamp 1, 25 s) |
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

## Kendte begrænsninger

- Alle figurer/miljø er proxies; ingen rigtige animationsklip.
- Portrætlayout er en prototype (tætte badges ved fulde etager).
- Nogle afvisningsårsager med tal fra reduceren vises på engelsk i dansk sprog (UI deaktiverer normalt handlingen med egen dansk årsag).
