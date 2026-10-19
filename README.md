# LASTROOT

> Defend the last world tree. Build a deck that can take root.
> Tre etager. To fraktioner. Ét hjerte, du ikke må miste.

Turbaseret roguelike-deckbuilder i **Godot 4.5.1 (typed GDScript)**, bygget efter *LASTROOT Godot Udviklingsbibel v2* (`docs/BIBLE.md` / `docs/LASTROOT_Godot_Udviklingsbibel_v2.pdf`). Grafikken bliver Synty/PolyPerfect med animationer fra Synty/PolyPerfect eller Mixamo; indtil pakkerne er importeret, kører hele spillet med registrerede greybox-proxies (`data/art/asset_slots.json`).

**Start her:** [`START_HERE.md`](START_HERE.md) · **Status:** [`docs/STATUS.md`](docs/STATUS.md) · **Assets:** [`docs/SYNTY_INTEGRATION.md`](docs/SYNTY_INTEGRATION.md)

## Hurtigt

```bash
godot --path .                                                  # spil (Godot 4.5.1)
tools/check.sh                                                  # validatorer + import + tests + scenesmoke
godot --headless --path . --script res://tests/run_tests.gd     # domæne- og prognosetests
godot --headless --path . res://scenes/tests/scene_smoke.tscn   # kampscene med rigtigt input
godot --headless --path . --script res://tools/balance/run_balance.gd -- --seeds=20
python3 tools/validate_plan.py --next                           # næste READY-opgaver
```

## Struktur (bibel s. 27)

| Sti | Ansvar |
|---|---|
| `scripts/domain/` | Regler og serialiserbar state: `Catalog`, `RngStream`, `BattleReducer` (eneste autoritet), `Forecast` (samme reducer på klon), `RunReducer` (rute, økonomi, belønninger), `AutoPlayer` (bot til tests/balance). Ingen noder. |
| `scripts/save/` | `SaveCodec`: kuvert med schema, checksum, presentation checkpoint. |
| `scripts/autoload/` | `GameSession` (kommandoindgang), `AppFlow` (skærme + UI-skalering), `SaveService` (atomisk skrivning, backup, eksport/import), `SettingsService`, `AudioService`; `scripts/core/loc.gd` (`Loc`). |
| `scripts/runtime/` | `TreeStage` (diorama, kamera), `UnitView`, `StageLayout` (faste anchors), `VisualBridge` → `scripts/runtime/visual/` (VisualSlots, proxies, UnitAnimator). |
| `scripts/presentation/` | `BattlePresenter`: afspiller reducerens events med timere (skip, 0.5/1/2×). |
| `scripts/ui/` | Kamp-HUD (`battle/`), `CardView`, `UiKit`, menu/rute/belønning/resultat (`menu/`, `flow/`). |
| `data/definitions/` | Katalog (24 kort, 8 relikvier, 4 mutationer, 5 kampe + boss) genereret fra `design/catalog.json`. |
| `data/art/` | VisualSlots: hvilken Synty/PolyPerfect-model og hvilke klip der hører til hvert væsen, fjende og trædel. |
| `tests/` + `fixtures/` | Domænetests (T01-T10 + én test pr. kort), 120 prognosescenarier, scenesmoke, savetests. |
| `docs/` + `evidence/` | Bibel, status, beslutninger, risici, ledgers, testrapporter, screenshots, balance. |
| `tools/` | check.sh, generatorer, validatorer, balance, Synty/PolyPerfect/Mixamo-importkæde, web-pakning. |
| `plan/tasks.json` | 36 opgaver i fire faser med status og beviser. |
