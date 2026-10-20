# Legacy save fixtures (LR-29)

Real saves written by the **first build** (commit `29da5a2`, envelope
`schema_version` 1), not hand-edited. They were produced by running
`gen_legacy_v1.gd.txt` (rename to `.gd`) inside `git archive 29da5a2` with
Godot 4.5.1, seed 4242, Barkvogteren:

| File | Phase when saved |
|---|---|
| `v1_battle.json` | battle 1, turn 1, after one played card |
| `v1_reward.json` | battle 1 won, card slot offered (presentation pending) |
| `v1_route.json` | all battle-1 rewards claimed, route N1 open |
| `v1_node.json` | node N1A (encounter) entered |

## What schema 1 looked like

Same envelope as today (`game_id`, `build_id`, `schema_version`,
`content_version`, `timestamp`, `checksum` = sha256 of canonical payload,
`payload.run`, `payload.presentation_checkpoint`). The **run** lacked four
fields added by later builds:

| Field | Added in | v1 → v2 migration (`SaveCodec.migrate_1_to_2`) |
|---|---|---|
| `mode` | demo mode (`ae6f457`) | `"full"` |
| `history` | result-screen history (`7ab2fe1`) | `[]` (earlier battles' rows never existed) |
| `heart_at_battle_start` | `7ab2fe1` | current `heart` |
| `claimed_choices` | playtest log (`9a2ad64`) | rebuilt from the reward/node slots still in the save |

The checksum is verified over the payload *as stored* (v1) before migrating.
After a migrated load the next save is written as schema 2, and the v1 file
becomes the backup (it still decodes). Tests: `tests/unit/test_save_hardness.gd`.
