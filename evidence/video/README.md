# Gameplay recordings (LR-34)

Real gameplay only. Every clip is the actual game (`scenes/battle`, `scenes/flow`, the real `GameSession` → `RunReducer`/`BattleReducer`) recorded with Godot's Movie Maker. The player is the project's bot (`AutoPlayer`) sending commands through `AutoDriver` at a human-like pace; nothing is generated, composited or edited apart from trimming the start and H.264 encoding. Each clip has a JSON log next to it written by the same run.

**Caveats**
- **All art and sound is placeholder** (procedural greybox proxies; no Synty/PolyPerfect/Mixamo assets). Clips must be re-recorded after the art import before any public use.
- **Software rendering**: Xvfb + Mesa llvmpipe, `gl_compatibility` renderer (the logs record `adapter: llvmpipe`). Movie Maker records at a fixed 30 fps in game time, so motion is smooth, but this says nothing about frame rate on real hardware.
- The bot plays; a human would hover/select cards before confirming. The bot's commands go through the same `GameSession.battle_cmd`/`cmd` as the UI buttons, so the forecast panel and playback are the real ones.

## Clips (recorded 20.10.2026, game code at commit `6e98bfb`, Godot 4.5.1-stable)

| File | Length · size | What it shows | Log |
| --- | --- | --- | --- |
| `forecast_turn.mp4` | 27.3 s · 1280×720 · 645 KB | Battle 1, Spore Sage. The forecast panel ("Forecast — end of turn") updates after each card; End turn plays back exactly that: turn 2 forecast "Ashling dies" ×2 → 2 deaths; turn 3 "Victory: every wave is defeated" → battle won. | `forecast_turn.json`: 3 end turns, `events_match_forecast: true` for each |
| `floor_battle.mp4` | 30.0 s · 1280×720 · 724 KB | Battle 3, Barkwarden. A Coalshield climbs Roots → Trunk → Crown (forecast lines "↑ Coalshield → Trunk/Crown"), then reaches the Heart for 3 (forecast "Heart 60 → 57", real 3 damage); last wave arrives on the Roots. | `floor_battle.json`: 3 end turns, 2 climbs, all match forecast |
| `mutation_choice.mp4` | 19.3 s · 1280×720 · 416 KB | Reward flow after battle 1: card choice, "The tree mutates" with all four mutations, Deep Roots chosen (header then shows "Deep Roots"), route, camp, then battle 2 with the Deep Roots proxy on the tree (extra roots over the back edge of the Roots floor and hanging below it; subtle in placeholder art — the header tag "Deep Roots" is the clear signal). | `mutation_choice.json`: `mutation_gained: M01` |
| `ash_crown_boss.mp4` | 30.0 s · 1280×720 · 858 KB | Battle 6, the Ash Crown (from turn 5), Spore Sage. Forecast shows the boss's HP drop per turn ("The Ash Crown ♥ 60→54 … 19→1"); the boss dies on turn 8, "Victory". | `ash_crown_boss.json`: 4 end turns, all match; times in the log are before the 2.4 s trim |

Total for the four clips ≈ 2.6 MB. Older clips from earlier commits (same method, 960×540): `battle1_spore_autoplay.mp4` (commit `c45bd64`), `run_bark_two_battles_autoplay.mp4` (`33d7ede`), `run_spore_two_battles_autoplay.mp4` (`fa9dcfb`).

"Matches forecast" in the logs means: before each End turn the logger stores `Forecast.end_turn()` of the live battle state (what the panel shows), and after the real End turn it compares the real resolution events with the forecast events (canonical JSON, exact). Death and Heart-damage counts are listed side by side.

## Exact commands

`tools/record_clip.sh <name> <WxH> -- <args>` runs Movie Maker under Xvfb on `scenes/tests/record_clip.tscn` (the same start as `boot.gd`: a `DebugFixtures` state + `AutoDriver`), then encodes with ffmpeg (libx264, CRF 30, yuv420p). Prefix `XDG_DATA_HOME=/tmp/…` to keep saves out of your own profile.

```bash
tools/record_clip.sh forecast_turn 1280x720 -- --setup=battle1 --faction=SPORE --seed=3 --autoplay=1 --max_seconds=28
tools/record_clip.sh floor_battle 1280x720 -- --setup=battle3 --faction=BARK --seed=2 --autoplay=1 --max_seconds=30
tools/record_clip.sh mutation_choice 1280x720 -- --setup=reward --faction=BARK --seed=1 --autoplay=1 --delay=1.6 --max_seconds=40 --battle_seconds=9
TRIM_START=2.4 tools/record_clip.sh ash_crown_boss 1280x720 -- --setup=boss --faction=SPORE --seed=3 --autoplay=1 --max_seconds=34
```

Same seed + setup gives the same run (the reducer is deterministic; `test_battle_matrix/test_deterministic_same_input_same_output`). Recording takes about 7× real time on the 4-core container.

## Demo build

The demo-end recording and screenshot from the exported demo build are in `evidence/demo/` (see `evidence/demo/result.json` and `docs/DEMO_PLAN.md`).
