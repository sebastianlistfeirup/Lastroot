# Hjemkomst · første session (LR-08/09/11/12/13 + balancebeslutning)

*Til dig, Sebastian. Én tjekliste fra `git pull` til de beslutninger, kun du kan tage. Regn med 3–4 timer; afsnit 1–2 (≈45 min) giver mest. Alle kommandoer herunder er kørt i containeren den 20.10.2026 (Linux, Godot 4.5.1) — undtagelser står ved kommandoen. Asset-oversigt pr. slot: `docs/ASSET_MAP.md`.*

**På Windows:** kør `.sh`-kommandoerne i **Git Bash** (følger med Git for Windows) fra projektmappen. Peg på konsol-udgaven af Godot, så du ser output:
`export GODOT_BIN="/c/Godot/Godot_v4.5.1-stable_win64_console.exe"` (ret stien). Python hedder ofte `python` eller `py` på Windows — brug det i stedet for `python3`, hvis `python3` ikke findes.

---

## 0. Klar (10 min)

- [ ] `git pull` (main) og åbn mappen i **Godot 4.5.1-stable** (samme version: `docs/VERSION_MATRIX.md`). Første åbning importerer i et par minutter.
- [ ] `tools/check.sh` → sidste linje skal være `validators_exit=0 loc_exit=0 tests_exit=0 smoke_exit=0 meta_exit=0` (i containeren: 118 tests, 40 smoke-checks, 628 meta-checks, 0 fejl). Kør den ikke samtidig med en anden testsuite/capture (de deler `user://`).
- [ ] `python3 tools/synty/doctor.py` → tjekker Godot-version, Pillow, xvfb (kun Linux), hvad der er pakket ud, dine valg, og at **ingen købte filer er i git**. Ændrer intet. `resultat: klar` = fortsæt.

## 1. Spil før du importerer (LR-08 / LR-09, ≈30 min)

Formål: se proxy-spillet med egne øjne på rigtig skærm, så du kan skelne "grafikken er ny" fra "spillet virker". Start: F5 i editoren, eller direkte i en kamp:
`godot --path . -- --setup=battle1 --faction=BARK` og `godot --path . -- --setup=battle1 --faction=SPORE`.

**Kamp 1 med Barkvogteren** (Hovedmenu → Nyt løb → Barkvogteren):

- [ ] Alle tre etager, hjertet og stammen er synlige uden at scrolle (LR-08).
- [ ] "Sådan spiller du" tilbydes ved første løb; teksten er forståelig.
- [ ] Bølge 1: 1 Askeling · bølge 2: 2 Askelinger · bølge 3: 1 Kulskjold — hver bølge varsles ("Wave n of 3"), ingen tidlig sejr, ingen dobbelt opstigning (LR-09).
- [ ] Prognosepanelet (højre) passer med det, der sker, når du trykker **Afslut tur** (`E`).
- [ ] Det er tydeligt, hvorfor hjertet mister liv.
- [ ] `2×` og "Skip animation" giver samme resultat som normal hastighed.
- [ ] Luk spillet midt i en tur, start igen → **Fortsæt** genskaber præcis samme hånd/state.
- [ ] Sejr → belønningsskærm; nederlag → resultatskærm.

**Kamp 1 med Sporevismanden:** samme liste, plus:

- [ ] Gift vises som ikon + tal på målet og tikker ved turstart.
- [ ] Sporevismandens angreb sender en turkis sporebolt.

**Notér de tre største friktioner** (hvad du ledte efter, hvad der overraskede): ________________________________

Bed derefter agenten markere LR-08/LR-09 med din observation (en menneskelig gennemspilning kan ikke bevises headless).

## 2. Læg pakkerne lokalt (10 min)

Læg de købte filer **uden for repoet**, fx:

```
D:/LASTROOT_vendor/
  Synty/POLYGON_Nature_SourceFiles.zip            (eller .unitypackage)
  Synty/POLYGON_DarkFantasy_SourceFiles.zip
  Synty/POLYGON_FantasyCharacters_SourceFiles.zip
  PolyPerfect/Low_Poly_Animated_Animals.unitypackage
  Mixamo/   Breathing Idle.fbx  Standing Up.fbx  Punching.fbx  Standing 1H Magic Attack 01.fbx
            Hit Reaction.fbx  Dying.fbx  Standing Block Idle.fbx  Victory.fbx  Walking.fbx
```

Hvilke pakker og hvorfor: `docs/ASSET_MAP.md` §0 (minimum: Nature, Dark Fantasy, Fantasy Characters, PolyPerfect Animals, 9 Mixamo-klip). Mixamo-indstillinger: §2.2 dér (FBX Binary, 30 fps, Without Skin, **In Place** på Walking). Downloadsiden hos Synty kan have en Godot-udgave; tag ellers "Source Files"/FBX.

`unpack.py` kopierer kun modeller og teksturer ind i `assets/quarantine/` (gitignored, `.gdignore`). Det er den eneste mappe i projektet, der indeholder købte råfiler; `assets/imported/` får kun de valgte filer.

## 3. Pipeline: pak ud → match → byg (20–40 min)

Kør fra projektmappen. Hver kommando giver en klar dansk/engelsk besked og stopper, hvis noget mangler (prøvet uden pakker: se §11).

```bash
python3 tools/synty/unpack.py "D:/LASTROOT_vendor/Synty/POLYGON_Nature_SourceFiles.zip"
python3 tools/synty/unpack.py "D:/LASTROOT_vendor/Synty/POLYGON_DarkFantasy_SourceFiles.zip"
python3 tools/synty/unpack.py "D:/LASTROOT_vendor/Synty/POLYGON_FantasyCharacters_SourceFiles.zip"
python3 tools/synty/unpack.py "D:/LASTROOT_vendor/PolyPerfect/Low_Poly_Animated_Animals.unitypackage"
python3 tools/synty/unpack.py "D:/LASTROOT_vendor/Mixamo"          # mappenavnet skal indeholde "Mixamo"
python3 tools/synty/doctor.py                                       # pakker + Mixamo-navne ok?
python3 tools/synty/match.py --report                               # se forslag uden at skrive
python3 tools/synty/match.py                                        # skriver data/art/synty_choices.json
python3 tools/synty/focus.py stage.floor_roots unit.B01 unit.S01    # LR-13: byg kun disse (§6)
tools/synty/build.sh                                                # stage -> import -> wrappers (op til 3 pas)
```

- `match.py` skriver kun **navne** (sikkert at committe). `"status"`: `auto` = bygges · `weak` = kun ét fælles ord, bygges først når du skriver `approved` · `none` = intet fundet · `skip` = behold proxy · `approved`/`manual` = låst ved næste `match.py`.
- Forkert model valgt? Kopiér en sti fra `"alternatives"` ind i `"source"` (eller skriv en fra `assets/quarantine/<pakke>/manifest.json`) og sæt `"status": "approved"`.
- Byg-rapport: `evidence/asset_pipeline/build_report.json` (højde, skala, facing, knoglekort, advarsler pr. slot).
- Første humanoide figur: `godot --headless --path . --script res://tools/synty/model_probe.gd -- res://assets/imported/<pakke>/<fil>.fbx` viser knogler, humanoid-match, klip, cm/m og op-akse (`docs/SYNTY_INTEGRATION.md` §6b). Retarget af en *rigtig* Synty/Mixamo-humanoid er det eneste led, der ikke er bevist i containeren.
- Exitkoder fra `build.sh`: 0 bygget · 1 en wrapper fejlede (se rapporten) · 2 manglende input (ingen Godot / ingen valgfil) · 3 intet at bygge (ingen auto/approved).

## 4. Hvad du kigger efter

Åbn i editoren og tryk **F6** (kør aktuel scene):

**`scenes/tests/asset_gallery.tscn` (style gate)** — taster `1` line-up (alle 18 figurer på tre hylder, 1 m-gitter) · `2` scene (tre etager, stamme, hjerte, baggrund) · `3` props/mutationer/FX · `4` gate (biblens udsnit: B01, S01, B02, S02, E01, E05) · `A` næste animationstilstand på alle · `R` reduced motion.

**`scenes/tests/rig_lab.tscn`** — én figur mod 1 m-kube, højdestang og pilen "front = −Z". `←`/`→` skift figur · `Space` næste tilstand · `R` reduced motion. Viser pr. tilstand: clip / procedural / **MISSING**, kontakttid og hvor hurtigt `finished` kom.

Sammenlign med dagens proxies (taget 20.10 under Xvfb/softwarerendering, ikke din GPU — farver og lys er vejledende):

| Billede | Hvad du sammenligner |
|---|---|
| `evidence/homecoming/gallery_lineup.jpg` | størrelsessprog: små 0,9–1,4 m, champions/3-pladsers ~2,3–2,6 m, boss 3,4 m |
| `evidence/homecoming/gallery_gate.jpg` | LR-13-udsnittet under ét lys |
| `evidence/homecoming/gallery_stage.jpg` | tre etager, stamme, hjerte (REF_05) |
| `evidence/homecoming/gallery_props.jpg` | props, mutationer, FX |
| `evidence/homecoming/riglab_B01.jpg`, `riglab_S01.jpg`, `riglab_B04.jpg`, `riglab_E06.jpg` | champions, firbenet Tornhjort, boss i RigLab |
| `evidence/homecoming/riglab_states_sheet.jpg` | alle 9 tilstande frosset midt i bevægelsen |
| `evidence/homecoming/battle_mid_1080p.jpg`, `battle_boss_1080p.jpg`, `battle_mid_portrait.jpg`, `battle_boss_portrait.jpg` | kampkamera (REF_01/REF_03), læsbare tal |
| `evidence/homecoming/stage_mutations_all.jpg`, `stage_mutations_none.jpg` | M01–M04 til/fra |
| `evidence/homecoming/heart_health_strip.jpg` | hjertets skadestilstande |
| `evidence/homecoming/menu_*.jpg`, `route_*.jpg`, `epilog_*.jpg` | dioramaer bag menu, rute (REF_04) og resultat |

Efter import, alt side om side (kun Linux/xvfb; på Windows: kør scenerne med F6 og tag skærmbilleder selv):
`tools/capture_all.sh efter_import --compare=proxies_baseline` → `evidence/captures/<dato>_efter_import/compare_proxies_baseline.html`. **Commit aldrig** disse mapper (de viser købt indhold; `.gitignore` udelukker dem).

## 5. Godkend / afvis pr. slot

En figur er **godkendt**, når alle fem er sande: ☐ højde passer (`scale_m` i `docs/ASSET_LEDGER.csv`) · ☐ fødder på gitteret (y=0) · ☐ vender mod pilen (−Z) · ☐ idle/attack(cast)/hit/death stabile (ingen posesnap) · ☐ materialet matcher naboerne under samme lys (`docs/ASSET_MAP.md` §1.4). Miljø: ☐ etageoverflade flad på y=0 og 11,6 m bred · ☐ intet foran enhedstal.

Skriv resultatet i `docs/ASSET_LEDGER.csv`: `review_status` = `APPROVED` (eller `REJECTED`), `source_path` = stien fra `synty_choices.json`, `checksum` = `sha256sum assets/quarantine/<pakke>/<fil>` (eller `sha256` fra pakkens `manifest.json`). `rights_status` ændres først, når du har bekræftet købet/licensen. Rækker, der ikke står som `PROXY`/`NEEDED`, bevares af `gen_slots.py`. Klip: `docs/ANIMATION_LEDGER.csv` → `review_status`, `duration_s` (fra RigLab/rapporten).

**LR-13-udsnit (biblen: træ, to champions, to normale væsner, to fjender):**

| Slot | Godkend | Afvis | Note |
|---|---|---|---|
| `stage.floor_roots` / `floor_trunk` / `floor_crown` | ☐ | ☐ | |
| `stage.trunk` | ☐ | ☐ | |
| `stage.heart` (behold proxy er et gyldigt valg) | ☐ | ☐ | |
| `unit.B01` Barkvogteren | ☐ | ☐ | |
| `unit.S01` Sporevismanden (hat + stav læsbare?) | ☐ | ☐ | |
| `unit.B02` Rodspire | ☐ | ☐ | |
| `unit.S02` Sporeunge | ☐ | ☐ | |
| `enemy.E01` Askeling | ☐ | ☐ | |
| `enemy.E02` Kulskjold (galleriets gate viser E05; begge er fine) | ☐ | ☐ | |
| Mixamo-sættet (9 klip) på humanoiderne | ☐ | ☐ | |

**Resten (efter LR-13):**

| Gruppe | Slots (☐ godkendt) |
|---|---|
| Væsner | ☐ B03 · ☐ B04 (quadruped, egne klip) · ☐ B05 · ☐ B06 · ☐ S03 (static) · ☐ S04 · ☐ S05 · ☐ S06 |
| Fjender | ☐ E03 · ☐ E04 · ☐ E05 · ☐ E06 Askekronen (krone ≤ 3,6 m, badge synligt) |
| Scene | ☐ stage.backdrop |
| Props | ☐ lantern · ☐ mushroom_cluster · ☐ crystal · ☐ root_arch · ☐ rock |
| Mutationer | ☐ M01 · ☐ M02 · ☐ M03 · ☐ M04 |
| FX (kun teksturer; bygges i Godot) | ☐ poison · ☐ heal · ☐ armor · ☐ thorns · ☐ growth · ☐ spore_bolt · ☐ bark_hit · ☐ ash_death · ☐ heart_pulse · ☐ heart_damage · ☐ summon_bark · ☐ summon_spore · ☐ ash_puff · ☐ wilt · ☐ wilt_spore · ☐ ember_trail · ☐ ring · ☐ floor_target |

## 6. Ét asset ad gangen (LR-13 "ved problemer")

Biblen: *behold samme sceneinterfaces og skift ét asset ad gangen.* `tools/synty/focus.py` gør det uden håndredigering:

```bash
python3 tools/synty/focus.py --list                   # status + "built"/"proxy" pr. slot
python3 tools/synty/focus.py unit.B01                 # kun B01 bygges næste gang (andre auto -> weak)
tools/synty/build.sh
# ... kig i RigLab / galleri / kamp ...
python3 tools/synty/focus.py --revert unit.B01        # ser forkert ud? tilbage til proxy med det samme
```

Rækkefølge: etager → stamme → B01 + S01 → B02, S02, E01, E02 → resten (`docs/ASSET_MAP.md` §9). Kør `tools/check.sh` efter hver gruppe: grafik må aldrig ændre regler, så alle tests skal stadig være grønne. Et `weak`-valg foreslås igen, næste gang du kører `match.py` (kun `approved`/`manual`/`skip` låses).

## 7. Windows-build (LR-12, 15 min)

Kræver Godots eksportskabeloner: *Editor → Manage Export Templates → Download and Install* (4.5.1). Derefter:

```bash
godot --headless --path . --export-release "Windows Desktop" builds/windows/Lastroot.exe
```

(I containeren er preset-navnet bekræftet; selve eksporten stoppede kun på manglende skabeloner i det isolerede testmiljø.)

- [ ] `builds/windows/Lastroot.exe` starter fra en **ren profil** (omdøb midlertidigt `%APPDATA%\Godot\app_userdata\LASTROOT` — Godots standardmappe for projektnavnet; verificér stien).
- [ ] Kamp 1 kan gennemføres; prognose = resultat; luk/genstart midt i → Fortsæt virker.
- [ ] Notér build-ID (`SaveCodec.BUILD_ID`; står også som `"build"` i spiltest-eksportfilen) og FPS-indtryk på din GPU.
- [ ] Gem en kort skærmoptagelse af kamp 1 (biblen beder om video for fase 1-porten).

Bed derefter agenten om LR-12 + fase 1-porten (`python3 tools/write_evidence.py` → `python3 tools/update_tasks.py <commit>`; `update_tasks.py` tager kun et commit-id og skriver straks i `plan/tasks.json`).

## 8. LR-09 udvidet: et helt løb med hver champion (≈2 × 25 min)

- [ ] Barkvogteren: hele løbet (5 kampe + Askekronen). Vælg mindst én mutation og én championretning (VÆRN / VREDE).
- [ ] Sporevismanden: hele løbet. Prøv GIFTMESTER eller LIVSVÆVER.
- [ ] Askekronen: ankommer tur 5, eskalerer fra tur 10; nederlag hvis den forlader Kronen — er det forståeligt fra skærmen?
- [ ] Ruten (REF_04): kun én af to mellemknuder kan vælges; pris/belønning er tydelig.
- [ ] Spiltestdata: Indstillinger → *Spiltestdata* → **Eksportér** efter hvert løb (`docs/PLAYTEST_GUIDE.md`). Giv filen til agenten.
- Tid pr. løb: ____ min (mål 20–30) · Hjerteliv tabt: ____ / ____ · Sværhed 1–5: ____ / ____

## 9. Balance A/B (LR-27, D24/D29)

Botten vinder 40/40 i baseline, og selv tilfældigt spil vinder ~73 % (`docs/BALANCE_NOTES.md`). **Prøv B direkte i spillet:** Indstillinger → Sværhedsgrad → *Svær* (D32, gælder nye løb). Spil ét løb på Standard og ét på Svær med samme champion. Beslut efter §8:

| Valg | Hvornår | Hvad agenten gør bagefter |
|---|---|---|
| ☐ **A — behold baseline** | løbene føltes spændende, du tabte hjerteliv | intet; D24 lukkes som "bekræftet" |
| ☐ **B — fjende-HP ×1,3** (= "Svær": Askeling 5→7, Kulskjold 9→12, Glødjæger 7→9, Sodbærer 12→16, Stenbrud 16→21, Askekronen 60→78) | du vandt let uden at kigge på prognosen | enten gør Svær til standard, eller ny D-linje i `docs/DECISIONS.md` → `design/catalog.json` → `python3 tools/gen_definitions.py` → `tools/make_forecast_fixtures.gd` → `run_balance.gd` før/efter |
| ☐ andet: ____ | | samme kæde, én variabelgruppe ad gangen |

Se varianterne selv (in-memory, ændrer ingen filer):

```bash
godot --headless --path . --script res://tools/balance/run_balance.gd -- --seeds=20
godot --headless --path . --script res://tools/balance/run_balance.gd -- --seeds=20 --bot=casual --enemy_hp=1.3
```

D29 (undslupne fjender tæller ikke som nederlag) bekræftes eller ændres i samme beslutning.

## 10. Afslut sessionen

- [ ] `git status`: **intet** under `assets/quarantine/`, `assets/imported/` (kun README), `evidence/captures/` (kun baseline). `python3 tools/synty/doctor.py` skal sige `ingen købte filer i git`.
- [ ] Commit: `data/art/synty_choices.json`, `data/art/slot_scenes.json`, `art/` (wrappers/knoglekort/materialer — små filer uden købt indhold), opdaterede ledgere.
- [ ] `tools/check.sh` grøn.
- [ ] Giv agenten: dine tre friktioner (§1), godkendt/afvist-listen (§5), Windows-resultatet (§7), spiltestfilerne (§8) og A/B-valget (§9).

## 11. Bevis: pipelinen uden pakker (20.10.2026, container)

Kørt med tomt `assets/quarantine/` og uden `data/art/synty_choices.json` — ingen trin skriver noget eller viser en Python-traceback:

| Kommando | Resultat |
|---|---|
| `python3 tools/synty/unpack.py /findes/ikke.unitypackage` | `FEJL: finder ikke …` + `ERROR: … does not exist`, exit 2 |
| `unpack.py` på en tom mappe / ødelagt fil / `.rar` | "indeholder ingen modeller …" / "kunne ikke læse … Er downloaden færdig?" / "ukendt pakketype … pak .rar/.7z ud først", exit 2 |
| `python3 tools/synty/match.py` | `FEJL: ingen udpakkede pakker i assets/quarantine/ …`, intet skrevet, exit 2 |
| `python3 tools/synty/stage.py` | `FEJL: data/art/synty_choices.json findes ikke endnu …`, exit 2 |
| `tools/synty/build.sh` | samme besked + "build.sh stoppet før import", exit 2 (Godot startes ikke) |
| `build.sh` med valg uden kilde | "Intet at bygge … Spillet bruger stadig proxies", exit 3 |
| `GODOT_BIN=forkert tools/synty/build.sh` | "FEJL: Godot findes ikke …", exit 2 |
| `python3 tools/synty/focus.py unit.B01` | "FEJL: data/art/synty_choices.json findes ikke …", exit 2 |
| `python3 tools/synty/doctor.py` | OK/NB-linjer, `resultat: klar`, exit 0 |
| `tools/synty/selftest.sh` (falske pakker, hele kæden, efter ændringerne ovenfor) | 22/22 PASS (`evidence/asset_pipeline/selftest.json`) |
