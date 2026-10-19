# Beslutninger

D01-D07 er bibelens v2-afklaringer (se `docs/BIBLE.md`, "Beslutningslog"). Nye beslutninger registrerer dato, problem, valg, alternativer, påvirket opgave og bevis. Alle D08+ er reversible implementeringsvalg taget i ferie-sessionen 19.10.2026.

| ID | Problem | Valg | Alternativer | Opgave | Bevis |
|---|---|---|---|---|---|
| D08 | Engineversion | Godot **4.5.1-stable**, typed GDScript. Samme som GENESIS ARK, så værktøjer/erfaring genbruges. | 4.4 / 4.6-dev | LR-01 | `docs/VERSION_MATRIX.md`, `tools/check.sh` |
| D09 | Spillets sprog | **Engelsk er kildesprog** i kode og data; dansk er oversættelse (`localization/translations.csv`, `name_da`/`text_da` fra biblen i kataloget). Samme model som GENESIS ARK D-025. | Dansk kilde | LR-07, LR-33 | `scripts/core/loc.gd` |
| D10 | State-repræsentation | Domænestate er rene Dictionaries/Arrays/ints (ingen noder); statiske reducers med typede signaturer. Klon = `duplicate(true)`, hash = kanonisk JSON (sorterede nøgler). Gør forecast-kloning, saves og hash-sammenligning trivielle og sikre. | Typed Resource-klasser | LR-02/03/06 | `scripts/domain/`, `JsonUtil.state_hash` |
| D11 | RNG | Egen 32-bit SplitMix-agtig generator; hver strøm er `{seed, salt, state}` (shuffle, route, reward). Kampen kopierer shuffle-strømmen ind i BattleState og skriver den tilbage ved kampslut. | Godot `RandomNumberGenerator` | LR-02 | `tests/unit/test_rng.gd` |
| D12 | Kommando vs. prognose | `end_turn` = `resolve_end_turn` (trin 4-8) + `begin_turn` (næste turs træk/bølge). Prognosen kører kun `resolve_end_turn` på en klon. Paritetstest sammenligner `resolved_hash` og alle events med `stage == "resolution"`. | Separat turstart-kommando | LR-06 | `tests/unit/test_forecast.gd` |
| D13 | Sejr midt i turen | Sejr afgøres også efter en spillerhandling, når sidste bølge er indsat og brættet er tomt. Nederlag tjekkes altid først. | Kun ved turafslutning | LR-03 | `test_t10`, `test_heart_zero_beats_victory` |
| D14 | R03 og Blomstring | S11 (fordobling) tæller **ikke** som "Gift-tildeling" for Sporelyset. | Tælle med | LR-15 | `scripts/domain/battle/battle_reducer.gd` |
| D15 | Angreb uden modstander | Enheder angriber forreste levende modstander på egen etage; uden modstander sker intet (fjender klatrer bagefter). | — | LR-03 | `test_t03` |
| D16 | Grenløft-position | B10 placerer væsnet bagest på etagen over. | Vælg position | LR-14 | `test_b10_branch_lift` |
| D17 | Dugdråben i hånden | Rabatten vises på alle besværgelser i hånden (enhver kan blive den første); flaget bruges af første spillede spell, også ved grundpris 0 (bibel T-kanter). | Kun vise ved valg | LR-07/15 | `test_zero_cost_spell_uses_dewdrop_flag` |
| D18 | Udbud | Kort: 3 forskellige blandt alle 22 normale. Mutation: alle uejede. Relikvie: 3 tilfældige uejede. Kun kortvalg kan springes over. Alle udbud genereres med reward-strømmen og gemmes før visning. | Fraktionsfiltrerede kort | LR-16 | `test_reward_offers_survive_reload` |
| D19 | Rute | 5 forgreningspunkter genereres ved runstart med route-strømmen; hver har to forskellige typer blandt lejr/kort/møde/fjernelse. | Fast rute | LR-16 | `test_route_has_five_branches_of_two_types` |
| D20 | Gift-tick | Skade = snapshot-værdien; derefter -1 på den aktuelle værdi (ny Gift fra fx S06 bliver stående, men tickes ikke i samme fase). | — | LR-04 | `test_new_poison_does_not_tick_twice` |
| D21 | Hjerteliv | Hjertet klemmes ved 0; hver undsluppen fjende skader `max(1, angreb)` én gang. | — | LR-03 | `test_heart_damage_is_at_least_one` |
| D22 | Logisk UI-størrelse | AppFlow sætter `content_scale_size`: 1920x1080 på desktop, ~430 px bredt i portræt, 1280 bredt på små landskabsskærme, så 48 px-hitflader forbliver fingerstore. | Fast 1920x1080 | LR-07/28 | screenshots `evidence/shots/` |
| D23 | Enhedstal | 2D-badges projiceret over hver enhed (ikke Label3D): skarp tekst, tap-mål >= 48 px, forskudte højder så naboer ikke dækker hinanden. | Label3D | LR-07/08 | `scripts/ui/battle/unit_badge.gd` |
| D24 | Balance-observation | Greedy-bot vinder 40/40, casual-bot (tilfældigt) ~73 %. Se `docs/BALANCE_NOTES.md` med målte varianter; forslag: fjende-HP ×1,3. Katalogtal **ikke ændret** (baseline); markeret til menneskelig spiltest i LR-27. | Skrue på tal nu | LR-27 | `evidence/balance/balance_report_greedy.json` |
| D25 | Grafiklag | Kampen spørger kun `VisualBridge.make(slot_id)`; asset-laget (`scripts/runtime/visual/`) afgør om det er Synty/PolyPerfect-wrapper eller proxy. Uden laget bygges simple registrerede proxies. | Direkte modelreferencer | LR-08/11/13 | `scripts/runtime/visual_bridge.gd` |
