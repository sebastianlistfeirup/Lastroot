# Hjemkomst · første session (LR-08/09/11/12/13 + balancebeslutning)

*Til dig, Sebastian. Én tjekliste fra `git pull` til de beslutninger, kun du kan tage. **Alle assets er valgt på forhånd** (`data/art/synty_selection.json`, begrundet i `docs/REALMREND_LESSONS.md`): du henter, pakker ud og bygger (§2–§3). Regn med 3–4 timer; afsnit 1–2 (≈45 min) giver mest. Alle kommandoer herunder er kørt i containeren den 20.10.2026 (Linux, Godot 4.5.1) — undtagelser står ved kommandoen. Asset-oversigt pr. slot: `docs/ASSET_MAP.md`.*

**På Windows:** kør `.sh`-kommandoerne i **Git Bash** (følger med Git for Windows) fra projektmappen. Peg på konsol-udgaven af Godot, så du ser output:
`export GODOT_BIN="/c/Godot/Godot_v4.5.1-stable_win64_console.exe"` (ret stien). Python hedder ofte `python` eller `py` på Windows — brug det i stedet for `python3`, hvis `python3` ikke findes.

---

## 0. Klar (10 min)

- [ ] `git pull` (main) og åbn mappen i **Godot 4.5.1-stable** (samme version: `docs/VERSION_MATRIX.md`). Første åbning importerer i et par minutter.
- [ ] `tools/check.sh` → sidste linje skal kun vise `…_exit=0` (validators, release, selection, loc, tests, smoke, meta, layout) (i containeren: 118 tests, 40 smoke-checks, 628 meta-checks, 0 fejl). Kør den ikke samtidig med en anden testsuite/capture (de deler `user://`).
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

## 2. Download-tjekliste: læg arkiverne lokalt (10–30 min)

**Alt er valgt på forhånd:** `data/art/synty_selection.json` er det bindende valg pr. slot. Hjemme skal du kun hente, pakke ud og bygge. Baggrund og begrundelser: `docs/REALMREND_LESSONS.md`.

> ⚠️ **SyntyPass udløber ca. 16.11.2026** (3 mdr. fra faktura SS-415943, 16.08.2026). Hent **alle** arkiver herunder, også de valgfri, *før* udløb, og beslut om fornyelse: videre udvikling med Synty-assets kræver aktivt abonnement (EULA §12.3).

Læg arkiverne **uden for repoet**, uåbnede, præcis med disse navne (fx dem du allerede har fra Realmrend i `assets_source/synty/` eller på backup-disken `G:\REALMREND Crowns at War`):

```
D:/LASTROOT_vendor/Synty/      <- alle .zip herunder, flad mappe
D:/LASTROOT_vendor/Optional/   <- valgfri pakker (Fantasy Rivals, PolyPerfect, Mixamo-mappe)
```

**Ejede arkiver (skal bruges af pipelinen — 12 stk.).** sha256/bytes fra Realmrends ledger (`asset_ledger.csv`, SYN-xx):

| ☐ | Arkiv | Bytes | sha256 |
|---|---|---|---|
| ☐ | `POLYGON_Fantasy_Kingdom_Godot_4_5_1_v1_0_0.zip` (SYN-15) | 105217496 | `e7fe0612344a43449ac5abac08b2a5bec17afd4153bf5d9e2b872a19fc8f9726` |
| ☐ | `POLYGON_Fantasy_Kingdom_SourceFiles_v5.zip` (SYN-16) | 375411418 | `281ca1fc820d98f72c054d3fd43ee805638122d1f48618d0a5f0dc5fef8d88c8` |
| ☐ | `POLYGON_Dark_Fantasy_Godot_4_6_2_v1_0_0.zip` (SYN-11) | 106758922 | `6b8b122d840aa3c5bf9b9422b50708345b139322b8c1dc26dc4ac2b45acd34ea` |
| ☐ | `POLYGON_Dark_Fantasy_SourceFiles_v3.zip` (SYN-12) | 143066623 | `39f54fa9abe3cf8144443533510239ad9cfe6d07715e74667fb2263fa1af4d9b` |
| ☐ | `POLYGON_Dungeon_Godot_4_5_1_v1_0_1.zip` (SYN-13) | 42283618 | `77aaaa7a519f2bc52640e70c4b08c20412ee8b07393c1f0d67233788827d4535` |
| ☐ | `POLYGON_Dungeon_Pack_SourceFiles_v3.zip` (SYN-14) | 54043765 | `e6be76712680d5dfc3052aad695c62776581c3778dbbcc329a228c20d7645f28` |
| ☐ | `ANIMATION_Base_Locomotion_SourceFiles_v3.zip` (SYN-01) | 96390430 | `948051cbc770380a86142bdea0ca3932e3b5b1a83863bda02c81bd0271020f3b` |
| ☐ | `ANIMATION_Sword_Combat_SourceFiles_v5.zip` (SYN-06) | 20432439 | `84ebd715f483302689cf08fabe6e9f5e506809b347311ebb5662b2d1d54d4f5e` |
| ☐ | `ANIMATION_Bow_Combat_SourceFiles_v1.zip` (SYN-02) | 77050534 | `303c6f4ccf1eb03f453ba54d136551fe0ac065113fc8a9d18fae106d688e5a66` |
| ☐ | `ANIMATION_Emotes_And_Taunts_SourceFiles_v1.zip` (SYN-03) | 78239321 | `2bbea3fb534843796ba04e7cfed5bad8ffa76ecbc29bac9c4b17e2f89c3244aa` |
| ☐ | `ANIMATION_Idles_SourceFiles_v3.zip` (SYN-05) | 65713449 | `6c185d31adedb92bd80827b28996f519b15fb43ae4d6c9658d24c344e0e73ad7` |
| ☐ | `ANIMATION_Goblin_Locomotion_SourceFiles_v2.zip` (SYN-04) | 69529408 | `92345d58c3438cfb2df89c91889e69902f1cc1202672f674c8c5342ed32c8beb` |

**Ejede, men ikke i slot-pipelinen (UI-sprites, valgfri senere — læg dem samme sted, så checksum-tjekket er komplet):**

| ☐ | Arkiv | Bytes | sha256 |
|---|---|---|---|
| ☐ | `INTERFACE_Dark_Fantasy_HUD_SourceSprites_v3.zip` (SYN-07) | 330390104 | `833f6db545e70e6ccf6c0a0ebed0aa212a90ddfd591d6b388ceede9ab4330c37` |
| ☐ | `INTERFACE_Dark_Fantasy_Menus_SourceFiles_v1.zip` (SYN-08) | 213353430 | `2faf614016bafe1e30c277399312121df2dbc06bdfbe230f55ddb6305242fe23` |
| ☐ | `INTERFACE_Fantasy_Menus_SourceFiles_v2.zip` (SYN-09) | 105433383 | `baf704df96f47bd9d3868fcafd6fb3599e2ce11908c5bbda4c49741b08afc250` |
| ☐ | `INTERFACE_Fantasy_Warrior_HUD_Source_Sprites_v3.zip` (SYN-10) | 211288035 | `06fb997e4811da5acee579d6c127fe656c5fec1acf369c19e770f146af4ff67e` |

**Skal hentes (`needs_download`, alle valgfri — uden dem falder slottet automatisk tilbage til en ejet model eller proxyen):**

| ☐ | Pakke | Hvorfra | Bruges til |
|---|---|---|---|
| ☐ | **POLYGON Fantasy Rivals** (Godot-build hvis den findes, ellers SourceFiles; navnet skal starte med `POLYGON_Fantasy_Rivals`) | SyntyPass-katalog (gratis med aktivt abonnement) | `unit.B06` Gammel Eg = Forest Guardian; reserve: Fort/Elemental Golem til B01/E05, Troll/Barbarian Giant til S06 |
| ☐ | **PolyPerfect Low Poly Animated Animals** (filnavnet skal indeholde `Animated_Animals`) | køb hos PolyPerfect (ikke SyntyPass) | `unit.B04` Tornhjort (firbenet, egne klip). **Eneste brug af PolyPerfect** |
| ☐ | Mixamo: `Standing 1H Magic Attack 01.fbx`, `Standing Up.fbx`, `Victory.fbx` (FBX Binary, 30 fps, Without Skin) i en mappe med "Mixamo" i navnet | mixamo.com (gratis) | kun reserve for `cast`/`summon`/`victory`, som ingen ejet Synty-animationspakke dækker |
| ☐ | POLYGON Nature / Enchanted Forest – Nature Biome | SyntyPass-katalog | kun til senere forsøg på stamme/rødder (i dag proxy) |

Tjek arkiverne (læser kun, skriver intet; ~1 min):

```bash
python3 tools/synty/apply_selection.py --archives "D:/LASTROOT_vendor"   # OK/MANGLER/FEJL pr. arkiv; exit 0 = alle 16 ok
```

`FEJL` = forkert størrelse/sha256 → hent arkivet igen. Godot-buildet af Dark Fantasy er lavet til Godot 4.6.2; det er fint, for pipelinen tager kun FBX/PNG ud af det. **Åbn aldrig** et Synty Godot-build som projekt i LASTROOT-mappen, og kopiér aldrig dets `Assets/`-mappe ind (på Windows lander den i `assets/` uden for de gitignorerede mapper — `doctor.py` fanger det).

## 3. Pipeline: pak ud → anvend valget → byg (20–40 min)

Kør fra projektmappen. Hver kommando giver en klar dansk/engelsk besked og stopper, hvis noget mangler.

```bash
# 1) Pak alle 12 model-/klip-arkiver ud i karantæne (gitignored). Godot-build OG SourceFiles af hver POLYGON-pakke.
for z in D:/LASTROOT_vendor/Synty/POLYGON_*.zip D:/LASTROOT_vendor/Synty/ANIMATION_*.zip; do python3 tools/synty/unpack.py "$z"; done
#    valgfri: python3 tools/synty/unpack.py "D:/LASTROOT_vendor/Optional/<Rivals/PolyPerfect>.zip"   og   ... "D:/LASTROOT_vendor/Optional/Mixamo"
python3 tools/synty/apply_selection.py --dry-run     # planen: slot -> præcis fil i karantæne, [alt n] = reserve brugt, [n matches] = tvetydigt
python3 tools/synty/apply_selection.py               # skriver data/art/synty_choices.json (status approved / skip = proxy)
python3 tools/synty/doctor.py                         # alt ok?
python3 tools/synty/focus.py stage.backdrop unit.B03 unit.S01 enemy.E06   # LR-13: start med de verificerede (§6)
tools/synty/build.sh                                  # stage -> import -> wrappers (op til 3 pas)
```

- **Ét-kommando-vej (efter unpack):** `python3 tools/synty/apply_selection.py && tools/synty/build.sh`. Exitkoder fra `apply_selection.py`: 0 alt fundet · 2 forkert input (intet skrevet) · 3 skrevet, men nogle *ejede* valg blev ikke fundet (de står som `skip` = proxy med en note; `MANGLER`-linjerne siger hvilke mønstre der blev prøvet) — `--allow-missing` giver 0.
- `match.py` behøves ikke længere (det er reserven, hvis du vil se andre forslag: `match.py --report`).
- **Ret et valg:** ændr `file`/`alternatives` i `data/art/synty_selection.json` og kør `apply_selection.py` igen. Eller skriv direkte i `synty_choices.json` (`"source": "<pakke>/<sti fra manifest.json>"`, `"status": "manual"`) — håndrettelser uden `"origin": "selection"` og `focus.py --revert` bevares; `--force` overskriver dem.
- **Tvetydige mønstre** (fx `*Mushroom*`): den bedste (FBX, `_01`, korteste sti) vælges, de næste står i `"alternatives"`. Kig dem igennem i galleriet.
- **Atlas:** `synty_choices.json → "atlas"` peger hver pakke på dens rigtige farveatlas (FK `Textures/PolygonFantasyKingdom_Texture_01_A.png`, DF `…/PolygonDarkFantasy_01_A.png`), også for SourceFiles-FBX'er, hvis egne materialer peger på manglende filer (Realmrend-lærdom, hvide modeller).
- **Klip:** ét fælles humanoid-sæt fra de ejede Synty-pakker: idle `A_Idle_Standing_Masc`, move `A_Walk_F_Masc`, hit `A_Hit_F_React_Sword`, death `A_Death_F_01_Sword` (verificeret i Realmrend), attack `A_Attack_LightCombo01A_Sword` (ellers verificeret `A_Attack_HeavyCombo01A_Sword`: sæt da `data/art/animation_sets.json → sets.humanoid.contact.attack` til `1.19`). cast/summon/victory/defend er valgfri (procedural, hvis de mangler).
- Byg-rapport: `evidence/asset_pipeline/build_report.json` (højde, skala, facing, knoglekort, advarsler pr. slot).
- Første humanoide figur: `godot --headless --path . --script res://tools/synty/model_probe.gd -- res://assets/imported/<pakke>/<fil>.fbx` viser knogler, humanoid-match, klip, cm/m og op-akse (`docs/SYNTY_INTEGRATION.md` §6b). FK-figurerne fra SourceFiles bruger UE-agtige knoglenavne (`Pelvis`, `UpperArm_L`, `lowerarm_l`, `Thigh_L`, `calf_l`, `Foot_L`) — mapperen kender dem, men det er ikke prøvet på en rigtig fil: se i RigLab, at armene er nede i idle og hovedet over bækkenet (`docs/REALMREND_LESSONS.md` §7).
- Mixamo-klip og -figurer i **hver sin mappe**: alt i en mappe med "Mixamo" i navnet behandles som klip.
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

Rækkefølge med det bindende valg (etager, stamme og hjerte forbliver proxy): de Realmrend-verificerede først — `stage.backdrop`, `unit.B03` (Soldier), `unit.S01` (Hermit), `enemy.E06` (Dark Lord), `prop.rock`, `prop.root_arch` — så B01, B02, S02, E01, E02 → resten (`docs/ASSET_MAP.md` §9). Kør `tools/check.sh` efter hver gruppe: grafik må aldrig ændre regler, så alle tests skal stadig være grønne. `focus.py` sætter også valg fra `apply_selection.py` til `weak` (bygges ikke). Kører du `apply_selection.py` igen, godkendes alle valgte slots igen (undtagen dem, du har sat tilbage med `--revert`).

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
| `python3 tools/synty/apply_selection.py --dry-run` (22.10.2026) | planen for alle 51 slots + 9 klip, intet skrevet, exit 0 (`evidence/asset_pipeline/selection_plan.txt`) |
| `python3 tools/synty/apply_selection.py` uden pakker | `FEJL: ingen udpakkede pakker …`, intet skrevet, exit 2 |
| `python3 tools/synty/test_selection_tools.py` (falske manifester med Realmrends rigtige filnavne; i `tools/check.sh`) | 23/23 PASS (`evidence/asset_pipeline/selection_tools_test.json`) |
| `tools/synty/selftest.sh` (falske pakker, hele kæden, efter ændringerne ovenfor) | 22/22 PASS (`evidence/asset_pipeline/selftest.json`) |
| `BPY_PYTHON=<python med bpy> tools/synty/humanoid_dryrun.sh --capture` (genererede humanoider, 20.10.2026) | 15/15 PASS (`evidence/asset_pipeline/humanoid_dryrun.json`); før rettelserne 6 FAIL (`humanoid_dryrun_before_fixes.json`) |

## Manglende assets → billede → Meshy → Godot (D36)

Slots uden ejet model (Thornhart, Old Oak) eller med svag pladsholder (hjerte, stamme, rødder, etager) prøves med arbejdsgangen i `docs/ASSET_GAP_WORKFLOW.md` (skill: `.claude/skills/lastroot-gap-asset/SKILL.md`). Start med én lille ting og 1–2 godkendte genereringer. Kræver Higgsfield MCP (eller en Meshy-API-nøgle) og en billedgenerator. Aldrig Synty-billeder som input.
