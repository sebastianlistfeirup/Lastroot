# Balancenoter (LR-27-forberedelse)

Katalogtallene er **uændrede** (biblens baseline). Nedenstående er eksperimenter på en kopi i hukommelsen (`tools/balance/run_balance.gd`), så du kan træffe beslutningen hurtigt efter en rigtig spiltest. Botter er regressionssignaler, ikke bevis for sjov (bibel s. 22).

- **greedy** = vælger hvert træk ud fra den rigtige prognose (nær optimal, kender reglerne perfekt).
- **casual** = spiller tilfældige lovlige kort uden at kigge frem (groft bud på en ny spiller).

| Variant | Bot | BARK sejre | SPORE sejre | Gns. tabt hjerteliv |
|---|---|---|---|---|
| Baseline | greedy | 20/20 | 20/20 | ~10 |
| Baseline | casual | 21/30 | 23/30 | ~54 |
| Fjende-HP ×1,3 | greedy | 20/20 | 20/20 | ~24 |
| Fjende-HP ×1,3 | casual | 4/20 | 4/20 | ~63 |
| Fjende-HP ×1,3, angreb ×1,25 | greedy | 20/20 | 20/20 | ~35 |
| Fjende-HP ×1,3, angreb ×1,25 | casual | 0/20 | 0/20 | ~64 |
| Fjende-HP ×1,5, angreb ×1,25, hjerte 50 | greedy | 15/20 | 15/20 | ~45 |
| Fjende-HP ×1,5, angreb ×1,25, hjerte 50 | casual | 0/20 | 0/20 | ~54 |

**Observation:** I baseline vinder selv tilfældigt spil ~73 %. Kampene slutter typisk før fjenderne når Kronen, så prognosen og etagevalgene betyder for lidt.

**Nu afprøvbart i spillet (D32):** Indstillinger → Sværhedsgrad → *Svær* = fjende-HP ×1,3 for nye løb. Genkørt gennem den rigtige kode: greedy 20/20 + 20/20 (~24 tabt hjerteliv), casual 4/20 + 4/20 (`--difficulty=hard`). Spil begge og vælg; vil du gøre Svær til standard, er det `DIFFICULTY_ENEMY_HP_PCT` i `scripts/domain/run/run_reducer.gd` eller tallene i kataloget.

**Forslag (ikke indført som standard):** start med *fjende-HP ×1,3* (Askeling 5→7, Kulskjold 9→12, Glødjæger 7→9, Sodbærer 12→16, Stenbrud 16→21, Askekronen 60→78). Det holder god leg sikker (greedy 100 %, men ~24 tabt hjerteliv) og gør tilfældigt spil til et nederlag i de fleste runs. Afprøv med mennesker før du låser det; registrér beslutningen i `docs/DECISIONS.md`, ret `design/catalog.json`, kør `python3 tools/gen_definitions.py`, regenerér prognosefixtures (`tools/make_forecast_fixtures.gd`) og genkør balance.

Genskab: `godot --headless --path . --script res://tools/balance/run_balance.gd -- --seeds=20 --bot=casual --enemy_hp=1.3` (flags: `--enemy_hp`, `--enemy_atk`, `--boss_hp`, `--heart`, `--resin`). Rapporter: `evidence/balance/balance_report_*.json`.

## Valg i bot-runs (LR-27, 21.10)

`python3 tools/balance/pick_report.py` → `evidence/balance/picks_<tag>.md`: hvilke kort, relikvier, mutationer og retninger runs slutter med, og sejre med dem. Fund: botten vælger kun kort ud fra værdi; relikvie-, mutations-, retnings- og lejrvalg er "første mulighed", så M01+M02 i 100 % og Root Sprout+ i 90 % er bot-artefakter, ikke dominans. Biblens krav "ingen kort/relikvie dominerer alle valg" kræver derfor menneskelige spiltest (eller en smartere bot, hvis det ønskes).

**Med spredte metavalg** (`--meta=seeded`: relikvie/mutation/retning/lejr/kortknude vælges ud fra hash af seed+slot): casual 80+80 runs → BARK 71/80, SPORE 66/80 sejre (~86 %, højere end 73 % med "første valg"). Ingen relikvie, mutation eller retning dominerer (alle 16–51 % af runs; sejrsandel med dem 65–100 %). Svage signaler at holde øje med i menneskelig test: R02 (25/25 sejre for BARK), R08 (lavest sejrsandel for SPORE, 17/26), Barkvogterens WRATH en anelse over BULWARK. Genskab: `godot --headless --path . --script res://tools/balance/run_balance.gd -- --seeds=80 --bot=casual --meta=seeded && python3 tools/balance/pick_report.py casual_metaseeded`.
