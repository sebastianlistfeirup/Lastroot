# LASTROOT · Butiksside, udkast (LR-34)

Udkast på engelsk (spillets kildesprog). Punkter er delt i **sandt i dag** og **planlagt**; planlagte punkter må ikke stå på en offentlig side, før de er bygget. Hvert "sandt i dag"-punkt har en bevis-kolonne (test, fil eller optagelse); kontrolleret mod koden på commit `6e98bfb` (20.10.2026, se "Kontrol" nederst).

## Short description (EN)

Defend the last world tree. Build a deck that can take root. A turn-based roguelike deckbuilder where three floors of a living tree stand between the ash and its turquoise Heart.

## Long description (EN)

The ash is climbing. Wave after wave arrives on the Roots, fights your creatures floor by floor and climbs towards the Crown. Whatever gets past the Crown strikes the Heart of the last world tree.

Choose your champion — the Barkwarden, a wall of bark and armor, or the Spore Sage, who poisons the ash before it climbs — and play cards onto the Roots, the Trunk and the Crown. A clear forecast shows exactly what ending the turn will do, so every loss is a decision you can learn from.

Between battles you choose your path: camps to upgrade a card, encounters, card rewards or removals. Mutations reshape the tree itself, relics bend the rules, and your champion grows along one of two paths. Five battles and the Ash Crown stand between you and victory.

## Feature bullets

**True today (in the current build):**

| Feature (EN, as it may appear) | Evidence |
| --- | --- |
| Turn-based battles on three floors (Roots, Trunk, Crown); each floor has a front position that fights first. | `data/definitions/catalog.json` `floors` (3), `rules.floor_capacity` [5,5,5]; `scripts/domain/battle/battle_reducer.gd` (index 0 = front); `test_battle_matrix/test_t03_enemy_climbs_once_without_second_fight`; clip `evidence/video/floor_battle.mp4` |
| An exact end-of-turn forecast that uses the same rules as the battle. | `scripts/domain/battle/forecast.gd` (real reducer on a clone); `test_forecast/test_forecast_matches_real_resolution` (120 stored scenarios); clip logs `evidence/video/*.json` (`all_end_turns_match_forecast: true` on all 10 end turns in the four clips) |
| Two champions (Barkwarden, Spore Sage) and 24 cards, 12 per champion, champion cards included. | catalog `cards` = 24 (10 creatures, 12 spells, 2 champions; 12 BARK + 12 SPORE); `test_catalog/test_24_types_22_normal_2_champions`, `test_cards/*` (one test per card) |
| 8 relics and 4 tree mutations. | catalog `relics` = 8 (R01–R08), `mutations` = 4 (M01–M04); `test_cards/test_relics_on_insert`, `test_run/test_mutation_after_battle_one_and_m04_once`, `test_battle_matrix/test_m01_adds_root_space`; clip `evidence/video/mutation_choice.mp4` |
| Five battles and a boss with its own rules (the Ash Crown). | catalog `normal_battles` = 5, `boss` = E06 "The Ash Crown"; `test_battle_matrix/test_boss_*` (anchoring, climbing, leaving the Crown loses, turn-10 escalation, immune to move/remove); `test_run/test_full_runs_with_both_champions`; clip `evidence/video/ash_crown_boss.mp4` |
| A branching route with camps, card rewards, encounters and card removal. | `test_run/test_route_has_five_branches_of_two_types`, `test_run/test_camp_upgrade_rules`, `test_removal_keeps_seven_normals`, `test_encounter_choices`; meta_smoke cases `route_*`, `camp`, `removal`, `encounter_*`, `card_node` |
| Card upgrades and champion paths (two per champion, two ranks) with before/after cards. | catalog `champion_paths` (B01: Bulwark/Wrath, S01: Venom Master/Lifeweaver); `test_cards/test_upgrade_matrix_all_cards`, `test_run/test_champion_path_locks`; `scripts/ui/flow/run_screen.gd` ("Now"/"After" cards); `evidence/meta_screens/reward_champion_desktop.png`, `node_camp_desktop.png` |
| Armor, Poison, Thorns and Growth, shown as symbol + number. | `test_battle_matrix/test_t01_*`, `t02_*`, `test_growth_*`; `evidence/meta_screens/cards_badges.png`; `docs/ACCESSIBILITY.md` |
| English and Danish. | `localization/translations.csv` (columns en, da); `python3 tools/loc_extract.py --check` (437 keys, 0 without Danish); `test_meta_flow/test_localization_complete`; meta_smoke `danish_cards`; `evidence/meta_screens/da_*.png` |
| Text size, reduced motion, animation speed and volume (master, music, effects) settings; Standard and Hard difficulty. | `scripts/autoload/settings_service.gd` (TEXT_SCALES, reduced_motion, ANIM_SPEEDS, VOLUME_KEYS, DIFFICULTIES); `test_meta_flow/test_settings_roundtrip`, `test_run/test_hard_difficulty_scales_enemy_hp_only`; scene_smoke "text size change rebuilds HUD"; `evidence/meta_screens/menu_settings_desktop.png` |
| Mouse, touch and keyboard. ¹ | scene_smoke "key selects a card", "Tab chooses a target", "Enter confirms the action", "E ends the turn"; meta_smoke `keyboard_*`; touch: `evidence/web_phone_flow/result.json` (12 steps, real touch events in Chromium phone emulation) |
| Linux and web builds (desktop browser); portrait layout for phone browsers. ² | Linux export run under Xvfb (`docs/STATUS.md`, `evidence/build_checksums.txt`); web export in headless Chromium (`evidence/web_phone_flow/`); meta_smoke `phone_battle_*`, `route_430x932` |
| Save after every action; continue exactly where you left off. | `scripts/autoload/game_session.gd` (`cmd()` saves after every accepted command); `test_save/*` (8 tests incl. `test_load_does_not_reroll_hand`); scene_smoke "load shows the finished result, nothing re-settled"; meta_smoke `resume_*`, `menu_continue` |
| A free demo: the first two battles with the same rules. ³ | `test_run/test_demo_mode_ends_after_two_battles`; `evidence/demo/result.json` (exported demo build played to "End of the demo") |

¹ Mouse/keyboard are driven by synthetic input events in the smoke tests, not by a person; touch only in browser emulation.
² The Windows build exports (`evidence/build_checksums.txt`) but has not been run on Windows yet, so "Windows" is under Planned. Phone layout is tested only in browser emulation (no physical phone).
³ Only once the demo has its own save slot: today the demo and the full game share one save file (see `docs/DEMO_PLAN.md`, "Demo-build check").

**Planned (not in the build yet, or not verified — do not publish as features):**
- Windows: the export exists, but it has not been run on a Windows machine (LR-12).
- Gamepad: menu buttons (A/B) and battle buttons (LB/RB, D-pad, A, Y, Start) are coded in `scripts/ui/battle/battle_screen.gd` and the menus. Since 21.10 `tests/scene_smoke.gd` drives a battle turn with simulated pad events (RB card, D-pad target, A confirm, Y end turn, Start/B menu). Still planned until a **real controller** has been tried.
- Final 3D art and animation (Synty Studios, PolyPerfect, Mixamo; pending import and licence check). Today all 3D is procedural placeholder geometry.
- Final sound and music (today: procedural placeholders).
- Native mobile builds and testing on real phones/tablets.
- Screen-reader support.
- Tested system requirements (no measurement on real hardware yet; all captures are software-rendered).

## Required screenshots (mapped to existing captures)

All from real builds; today's captures show placeholder art and must be retaken after the art is imported. All paths below exist on `6e98bfb` (checked 20.10.2026).

| # | Subject | Existing capture (placeholder art) |
| --- | --- | --- |
| 1 | Battle in progress, hand + forecast (desktop) | `evidence/meta_screens/battle_mid_desktop.png`, `evidence/shots/battle_mid_1080p.png` |
| 2 | Boss battle (the Ash Crown) | `evidence/shots/battle_boss_1080p.png` |
| 3 | Card target selection with preview | `evidence/shots/battle_select_spell.png`, `evidence/shots/battle_preview_spell.png` |
| 4 | Route map with branch choice | `evidence/meta_screens/route_b4_desktop.png`, `evidence/meta_screens/route_boss_desktop.png` |
| 5 | Champion path choice (before/after) | `evidence/meta_screens/reward_champion_desktop.png` |
| 6 | Camp upgrade | `evidence/meta_screens/node_camp_desktop.png` |
| 7 | Champion select | `evidence/meta_screens/menu_faction_desktop.png` |
| 8 | Card overview | `evidence/meta_screens/cards_desktop.png` |
| 9 | Portrait phone (battle + route) | `evidence/meta_screens/battle_mid_phone.png`, `evidence/meta_screens/route_b1_phone.png` |
| 10 | Run result (the tree) | `evidence/meta_screens/result_won_desktop.png` |
| 11 | Tree mutation choice | `evidence/meta_screens/reward_mutation_desktop.png` |
| 12 | Demo end screen | `evidence/meta_screens/result_demo_desktop.png`, `evidence/demo/demo_complete_1280x720.png` (exported demo build) |

Gameplay clips (real game, Movie Maker; list with commands in `evidence/video/README.md`): forecast turn, floor battle with climbing enemies, mutation choice, Ash Crown boss.

Do not use `references/REF_*.jpeg` (concept images) on the store page.

## Kontrol (20.10.2026)

- Rettet: "24 cards" præciseret (12 pr. champion, inkl. championkortet); "Each turn new enemies arrive" → "Wave after wave" (kampe har 3 bølger, ikke en ny hver tur); "front line next to the trunk" → front pr. etage (reglen er "indeks 0 er fronten", ikke placering ved stammen); "Desktop (Windows, Linux)" → Linux + web, Windows flyttet til planlagt (ikke kørt på Windows); gamepad flyttet til planlagt (battle-knapperne var ikke testet; den gamle tekst "simulated in tests" var kun sand for menuernes A/B). 21.10: simuleret pad i kamp nu testet i scene_smoke; rigtig controller mangler stadig.
- Tilføjet (verificeret): sværhedsgrad Standard/Hard, demo (med forbehold for fælles save).
- Skærmbilledtabellen: alle 14 oprindelige stier findes; to rækker tilføjet (mutation, demo-slut).
