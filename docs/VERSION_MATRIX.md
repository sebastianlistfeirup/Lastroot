# Versionsmatrix

| Komponent | Låst version | Kilde / bemærkning |
|---|---|---|
| Godot Engine | **4.5.1-stable (official, f62fdbde1)** | `Godot_v4.5.1-stable_linux.x86_64` fra github.com/godotengine/godot/releases. Brug samme version på Windows (`Godot_v4.5.1-stable_win64.exe`). Samme engine som GENESIS ARK, så værktøjskæden kan genbruges. |
| Export templates | 4.5.1.stable | `Godot_v4.5.1-stable_export_templates.tpz`; afprøvet: `linux_release.x86_64`, `windows_release_x86_64.exe`, `web_nothreads_release.zip`. |
| Sprog | GDScript (typed) | Ingen C#/.NET, ingen GDExtensions, ingen tredjeparts-addons. |
| Renderer | Forward+ (desktop) | `rendering_device/fallback_to_opengl3` slået til. Web/mobil: GL Compatibility. Screenshots i containeren: `--rendering-method gl_compatibility` under Xvfb + Mesa llvmpipe. |
| Save schema | 1 | `scripts/save/save_codec.gd` (`SCHEMA_VERSION`). Fremtidige versioner afvises uden at slette filen. |
| Content version | `0.1.0+lastroot-v2-baseline` | `data/definitions/catalog.json`, genereret fra `design/catalog.json` med `tools/gen_definitions.py`. |
| Prognose-fixtures | 120 scenarier | `fixtures/forecast/scenarios.json` (genereres med `tools/make_forecast_fixtures.gd`). |
| Python (værktøjer) | 3.10+ | Kun standardbibliotek. |

Engineopgradering midt i en fase kræver en konkret grund, rollback og regressionskørsel (bibel s. 25).
