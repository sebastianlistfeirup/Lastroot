# AGENTS.md — LASTROOT (regler for kodeagenter)

Brugerens seneste instruktion går forud for biblen; biblen (`docs/BIBLE.md`, PDF i `docs/`) er baseline; afvigelser og præciseringer registreres i `docs/DECISIONS.md`. Startpakkens originale AGENTS/CLAUDE/START_HERE ligger i `archive/`.

## Læs før du ændrer kode
`START_HERE.md` → `docs/STATUS.md` → `docs/DECISIONS.md` → `plan/tasks.json` → relevante bibelsider (mandat s. 3, regler s. 6-15, prognose s. 17, animation s. 19, domæne/save s. 20, testmatrix s. 21, faser s. 23, agentstyring s. 26, repo s. 27, kommandoer s. 28).

## Arbejdsgang
1. `git status` og seneste commit. Bevar eksisterende ændringer; ingen destruktiv reset.
2. `tools/check.sh` skal være grøn før og efter din ændring.
3. Tag næste READY-opgave (`python3 tools/validate_plan.py --next`). Én lille, sammenhængende ændring ad gangen.
4. Kør tests, gem beviser: `python3 tools/write_evidence.py` skriver `evidence/<task>/result.json` ud fra de faktiske rapporter. Opfind aldrig kørsler; `NOT_RUN` er ikke `PASS`.
5. `python3 tools/update_tasks.py <commit>` opdaterer `plan/tasks.json`; opdatér `docs/STATUS.md`; commit.

## Arkitekturregler
- `scripts/domain/` og `scripts/save/save_codec.gd` refererer aldrig noder, scener eller autoloads. Al regel-logik bor her og testes headless.
- **BattleReducer er eneste autoritet.** `BattleReducer.apply(state, cmd)` returnerer ny state + events; en afvist kommando ændrer intet. Forecast kører samme `resolve_end_turn` på en klon — aldrig en separat beregner.
- UI og 3D sender kommandoer via `GameSession.cmd(...)` / `GameSession.battle_cmd(...)` og læser state. De ændrer den aldrig.
- Præsentation (`scripts/presentation/`, `scripts/runtime/`) afspiller events med timere; ingen animation, lyd eller callback må ændre skade, død eller belønning. Manglende klip må aldrig låse flowet.
- Kun stabile ID'er og primitive værdier i saves. Ingen noder, AnimationTree eller afledte caches.
- Balance er data: `design/catalog.json` er baseline → `python3 tools/gen_definitions.py` → `data/definitions/catalog.json`. Ændr én variabelgruppe ad gangen, kør `tools/balance/run_balance.gd` før/efter, notér i DECISIONS.
- **Spillet er kun på engelsk (D34).** Al spillertekst skrives på engelsk via `Loc.t("…")` eller datafelter (så et sprog kan tilføjes senere); `localization/translations.csv` er strenginventaret (`python3 tools/loc_extract.py`), dens `da`-kolonne er hvilende og vises ikke. Dokumentation til ejeren er på dansk.
- Grafik er VisualSlots (`data/art/asset_slots.json`). Købte vendorfiler (Synty, PolyPerfect, Mixamo) må aldrig committes — repoet er offentligt. Wrappers og egne varianter er projektejede. Det bindende assetvalg er `data/art/synty_selection.json` (`tools/synty/apply_selection.py`); erfaringer fra Realmrend i `docs/REALMREND_LESSONS.md`.
- **Manglende assets (D36):** prøv arbejdsgangen billede → AI-scan (Meshy) → Godot-genopbygning i `docs/ASSET_GAP_WORKFLOW.md` via skill'en `.claude/skills/lastroot-gap-asset/SKILL.md` (wrapper om vendoreret `image-to-3d-rebuild`, MIT). Aldrig Synty/PolyPerfect-materiale som input til generativ AI (Synty EULA §1.4). Betalte genereringer kun i det antal ejeren har godkendt. Codex: skills ligger i `.claude/skills/<navn>/SKILL.md` — læs filen direkte.
- Typed GDScript, snake_case filer, PascalCase `class_name`. `const X := KlasseNavn` er ikke et konstantudtryk i 4.5 — brug klassenavnet direkte. Ingen funktion må hedde `wrap` (global).
- Ingen nye fraktioner, etager, multiplayer eller meta-progression uden nyt mandat.

## Kommandoer
```bash
tools/check.sh                                                   # validatorer, import, parse, tests, scenesmoke
godot --headless --path . --import --quit-after 2000             # opdatér klasse-cache efter ny class_name
godot --headless --path . --script res://tests/run_tests.gd      # domæne + prognose (evidence/test_report.json)
godot --headless --path . res://scenes/tests/scene_smoke.tscn    # kampscene med rigtigt input (evidence/scene_smoke.json)
godot --headless --path . res://scenes/tests/compile_all.tscn    # parse-tjek af alle scripts
godot --headless --path . --script res://tools/make_forecast_fixtures.gd   # kun efter bevidst regelændring
godot --headless --path . --script res://tools/balance/run_balance.gd -- --seeds=20
xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1920x1080 -- --setup=midbattle --capture=evidence/shots/x.png
godot --headless --path . --export-release "Windows Desktop" builds/windows/Lastroot.exe
```
`--setup` (DebugFixtures): `battle1`, `midbattle`, `battle2`..`battle6`, `boss`, `reward`, `route`, `node:<camp|card|encounter|removal>`, `won`, `lost`; `--faction=BARK|SPORE`, `--seed=N`.

> Bemærk: tests og smokes skriver i `user://` (saves/settings). Kør aldrig to testsuiter samtidig på samme maskine (fx i to worktrees) — de deler den mappe og kan give falske fejl.

## Efter hjemkomst (FULL-profil)
Én koordinator ejer `main`, scope og integration. Højst to specialister med adskilte filområder og egne worktrees; specialistcommits integreres først efter kontrakt- og gameplaykontrol (`templates/specialist_task.md`).

## Når noget stopper
Højst tre dokumenterede løsningshypoteser på samme fejl. Gem logs, lav mindste reproduktion, tag en anden READY-opgave. `BLOCKED_ENVIRONMENT` er ikke godkendt.
