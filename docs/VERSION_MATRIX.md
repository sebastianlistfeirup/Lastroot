# Versionsmatrix

| Komponent | Låst version | Kilde / bemærkning |
|---|---|---|
| Godot Engine | **4.7.1-stable (official, a13da4feb)** — fra 22.10 (D35) | `Godot_v4.7.1-stable_linux.x86_64` / Windows `Godot_v4.7.1-stable_win64.exe` (brug `_console.exe` til scripts: pålidelig exit-kode). Samme version som Realmrend; opfylder Synty Dark Fantasy Godot (≥ 4.6.2), Dungeon og Fantasy Kingdom (≥ 4.5.1). Rollback: grenen før `D35`-commit kører på 4.5.1-stable (f62fdbde1). |
| Export templates | 4.7.1.stable | `Godot_v4.7.1-stable_export_templates.tpz`; afprøvet 22.10: Linux (kørt under Xvfb), Windows (eksporteret, ikke kørt), Web + Web Demo (headless Chromium: menu nået, 0 fejl). |
| Sprog | GDScript (typed) | Ingen C#/.NET, ingen GDExtensions, ingen tredjeparts-addons. |
| Renderer | Forward+ (desktop) | `rendering_device/fallback_to_opengl3` slået til. Web/mobil: GL Compatibility. Screenshots i containeren: `--rendering-method gl_compatibility` under Xvfb + Mesa llvmpipe. |
| Save schema | 2 (v1 migreres, D33) | `scripts/save/save_codec.gd` (`SCHEMA_VERSION`). Fremtidige versioner afvises uden at slette filen. |
| Content version | `0.1.0+lastroot-v2-baseline` | `data/definitions/catalog.json`, genereret fra `design/catalog.json` med `tools/gen_definitions.py`. |
| Prognose-fixtures | 120 scenarier | `fixtures/forecast/scenarios.json` (genereres med `tools/make_forecast_fixtures.gd`). |
| Python (værktøjer) | 3.10+ | Kun standardbibliotek. |

Engineopgradering midt i en fase kræver en konkret grund, rollback og regressionskørsel (bibel s. 25).
