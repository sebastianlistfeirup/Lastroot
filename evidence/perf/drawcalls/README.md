# Draw calls: procedural proxies merged (ProxyMerge)

Measured 2026-10-20 in the cloud container: Godot 4.5.1, `gl_compatibility`, Xvfb + llvmpipe (software
rasterizer, 4 CPUs shared with other agents), 1920×1080. Frame times are CPU-rasterizer numbers, not a
player-hardware claim; draw calls/objects are exact and reproducible.

## Battle (tools/profile/stress_profile.gd → `stress_profile_before.json` / `../stress_profile.json`)

| State | Draw calls | Objects | Nodes | Idle p50 / p95 ms | Replay p50 / p95 ms |
|---|---|---|---|---|---|
| midbattle (6 units) | 1238 → **388** (−69 %) | 1784 → 934 | 1645 → 526 | 491 / 565 → 343 / 404 | 459 / 545 → 342 / 396 |
| boss (10 units) | 1732 → **522** (−70 %) | 2365 → 1155 | 1975 → 650 | 486 / 587 → 359 / 411 | 271 / 369 → 365 / 410 |
| full_tree (27 units) | 2722 → **1016** (−63 %) | 3816 → 2110 | 2573 → 1000 | 368 / 843 → 371 / 429 | 534 / 620 → 362 / 416 |

Primitives are unchanged within +5 % (merged meshes are culled as a whole). Frame times are noisy here
(llvmpipe is fill-rate bound and other agents were running); read them as "not worse, mostly better".
Load (cold / warm ms): menu 1001/527 → 1042/391, battle 1277/1173 → 996/760. The first bake of all
proxies costs ≈ 70 ms once per process (`tools/profile/merge_cost.gd`); later builds reuse cached meshes.

## Per subsystem, 3D pass draw calls (tools/profile/drawcall_breakdown.gd → `breakdown_before.json` / `breakdown_after.json`)

Measured by hiding each subsystem in turn. The 2D canvas (HUD, unit badges) is untouched.

| | midbattle | boss | full_tree |
|---|---|---|---|
| floors (floor + trunk ×3) | 709 → 83 | 709 → 83 | 709 → 83 |
| units (incl. side-rim overlay pass) | 260 → 62 | 645 → 137 | 1316 → 312 |
| mutations | – | 70 → 20 | 70 → 20 |
| heart | 28 → 10 | 28 → 10 | 28 → 10 |
| backdrop | 40 → 32 | 40 → 32 | 40 → 32 |
| 3D total | 1037 → 187 | 1492 → 282 | 2163 → 457 |
| 2D canvas (UI) | 201 | 240 | 559 |

Dioramas (total draw calls): menu 893 → 152, route 418 → 117, epilog 744 → 145.

The largest remaining item in full_tree is now the 2D canvas (559, mostly the 27 unit badges,
`scripts/ui/battle/unit_badge.gd`), which this change does not touch.

## Visual parity (`parity_diff.json`, `*_before_after_diffx4.jpg` = before | after | |diff|×4)

`tools/profile/parity_shots.sh` with `--fixed-fps 60` (two baseline runs are bit-identical for the battle
states). Before = clean export of 1e6c973, after = this branch:

| Shot | mean abs Δ (0-255) | pixels Δ>8 | pixels Δ>32 |
|---|---|---|---|
| battle midbattle | 0.005 | 0.018 % | 0.002 % |
| battle boss | 0.006 | 0.020 % | 0.002 % |
| battle full_tree | 0.013 | 0.075 % | 0.002 % |
| gallery line-up | 0.007 | 0.015 % | 0.002 % |
| gallery stage / menu / route / epilog | 0.04–0.14 | 0.08–0.22 % | 0.05–0.17 % (particles; baseline vs baseline: 0.13 %) |

The remaining differences are single edge pixels (rasterization of coplanar faces, overlay draw order).
Shape, colour and lighting are unchanged.

Reproduce: `tools/profile/parity_shots.sh <dir> [project]`, then
`python3 -I tools/profile/parity_diff.py <before> <after> --sheet=<dir>`;
`... res://tools/profile/drawcall_breakdown.tscn -- --out=<json> [--no-merge]` (A/B in one build).
