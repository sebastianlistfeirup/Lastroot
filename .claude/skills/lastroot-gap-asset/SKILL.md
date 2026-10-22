---
name: lastroot-gap-asset
description: Make a missing LASTROOT 3D asset (a visual slot with no owned Synty/PolyPerfect model, or a weak procedural proxy) with the image → AI scan → Godot rebuild workflow, and plug it into the game through VisualSlots. Use when the owner asks for a gap asset, names a slot from docs/ASSET_GAP_WORKFLOW.md, or a slot in data/art/synty_selection.json is keep_proxy / needs_download and should get a real model. Wraps the vendored image-to-3d-rebuild skill with the project's rules. Not for owned Synty models (use tools/synty) and not for FX (fx_builder.gd).
---

# LASTROOT gap asset (image → scan → Godot rebuild → VisualSlots)

Read in this order, then follow `.claude/skills/image-to-3d-rebuild/SKILL.md` step by step:
`AGENTS.md` → `docs/ASSET_GAP_WORKFLOW.md` (Danish, binding for this project) →
the slot in `data/art/asset_slots.json` + `data/art/synty_selection.json` → `docs/REFERENCE_GUIDE.md`.
Report to the owner in Danish; code, filenames and in-game text in English (D34).

## Hard rules (override the generic skill where they differ)
1. **Never put a Synty or PolyPerfect asset, render or screenshot into any generative AI**
   (image generators, Meshy, Tripo, Higgsfield, critics). Synty EULA §1.4 (see
   `docs/REALMREND_LESSONS.md`). Reference images are new text-prompted images or the owner's
   own drawings. `references/REF_*.jpeg` may be used as *style* input only if the owner says so
   for that asset; they never ship.
2. **Paid generations:** preflight the price, submit exactly the number the owner approved in
   this conversation, never resubmit after a timeout (look the job up). No auto-approver: the
   upstream `approver_mcp.py` is deliberately not vendored. Never edit the owner's settings.
3. **The scan is not the asset.** Scans live in `assets/generated_src/<slot_id>/` (gitignored).
   The deliverable is a procedural Godot rebuild under `art/generated/<slot_id>/`.
4. **Presentation only.** The asset and its animations never change rules, damage, deaths,
   rewards or timing of outcomes. All waits stay timers in the presenter.
5. **Style match to the rest of the game:** POLYGON-style low poly, flat-shaded facets, the
   palette in `data/art/palette.json` (turquoise heart, amber bark, violet spore, ash black +
   ember). Default material = palette colours per material class; baking the scan's paint is
   optional and only when it still reads as low poly (`paint` 0–1 control, default ≤ 0.5).
6. **Budget per slot:** unit ≤ 8k tris, boss ≤ 15k, stage piece ≤ 20k; one surface per material
   class (2–5); no per-instance unique materials (draw calls, see `evidence/perf/drawcalls/`).
7. **Animation:** Disney's 12 principles at **50 %** where they fit (anticipation, fast action,
   hit frame, follow-through/overlap, organic tilt), never linear, never cartoony. Respect the
   contact times in `data/art/animation_sets.json` (attack contact 0.30 s, cast 0.38 s) and
   reduced motion (`UnitAnimator.reduced_motion`).
8. Repo is public: commit only the rebuild script/scene, small baked textures (webp/png
   ≤ 1 MB each) and the ledger rows. Not the scan, not the reference image if it is not ours.

## Plug into the game (VisualSlots contract)
- Scene: `art/generated/<slot_id>/<slot_id>.tscn`, root `Node3D`, model facing **-Z**, feet/base
  at y = 0, real size in metres matching the slot's `height` (`fit: "height"`), pivot at the
  footprint centre. A child `Model` holds the meshes (the proxy animator moves `Model`, never
  the root).
- Animated slots (units/enemies/boss): an `AnimationPlayer` named `LRAnimations` with library
  `lr` and one animation per state in the slot's `animation_states`
  (idle loops; attack/cast must reach the hit frame at the contact time; death ends hidden or
  flat). Missing states fall back to procedural tweens automatically.
- Register: set `"scene": "res://art/generated/<slot_id>/<slot_id>.tscn"` (+ `scale`,
  `offset`, `rotation_y` if needed) on the slot in `data/art/asset_slots.json`. A hand-set
  scene wins over the Synty builder's mapping. Set the slot's decision in
  `data/art/synty_selection.json` to `"generated"` with the job id.
- Static parts that never animate get baked by `ProxyMerge` only for proxies; generated
  scenes should already be merged per material class.

## Verify before reporting (every round)
1. `tools/check.sh` green (`XDG_DATA_HOME=/tmp/xdg_gap` if other agents run).
2. Asset gallery: `xvfb-run -a godot --path . --rendering-method gl_compatibility res://scenes/tests/asset_gallery.tscn`
   and RigLab (`res://scenes/tests/rig_lab.tscn`) for animated slots: look at every state.
3. In a real battle: `-- --setup=midbattle` (or `boss`) `--capture=evidence/gap_assets/<slot_id>_battle.png`.
   Badge height, footprint ring and target ring must sit right; numbers stay readable.
4. Draw calls: `godot --headless --path . res://tools/profile/drawcall_breakdown.tscn` before/after, no big regression.
5. Look at the images yourself; numeric checks alone missed broken poses in Realmrend.

## Record
- `docs/ASSET_LEDGER.csv`: `source_pack` = "Generated (Meshy vN via <route>) + Godot rebuild",
  job id in `source_path`, `rights_status` = owner's Meshy plan terms (check: paid plans own the
  output; free tier may be CC BY), `review_status` = `GENERATED_REVIEW`.
- `evidence/gap_assets/<slot_id>/`: reference image if ours, 4-view scan renders, side-by-side
  scan vs rebuild, battle capture, `result.json` (job id, cost, tris, draw calls, checks).
- One line in `docs/DECISIONS.md` if a slot changes from Synty/proxy to generated.
