# LASTROOT · Asset-kort (slot → pakke → prefab → animation)

*Til dig som ejer, til første session med de købte pakker (LR-11/LR-13/LR-18). Trinvis arbejdsgang: `docs/HOMECOMING.md`. Værktøjskæden: `docs/SYNTY_INTEGRATION.md`. Søgemønstre pr. slot i maskinform: `data/art/vendor_suggestions.json` (genereret af `tools/synty/gen_slots.py`, ligesom `docs/ASSET_PLAN.md`).*

> **Ærlighedsnote.** Ingen købt pakke er åbnet i dette repo, og intet er downloadet. Pakkenavnene er rigtige produktlinjer; **alle prefab-, mesh-, tekstur- og klipnavne er "kandidat — verificér i pakken"**: typiske Synty-/PolyPerfect-konventioner (`SK_Chr_*` = rigget figur, `SM_Chr_*` = statisk figur, `SM_Env_*` = miljø, `SM_Prop_*` = rekvisit, `SM_Wep_*` = våben, `SM_Bld_*` = bygning, `FX_*` = partikler), ikke kontrolleret mod dine filer. Mixamo-klipnavnene er søgeord på mixamo.com; de fleste er velkendte, men tjek stavningen i søgefeltet. Pakkenavne markeret *(usikkert produktnavn)* skal slås op i butikken. `rights_status` i ledgerne er og bliver `purchased_unverified`, indtil du har bekræftet købet og indsat sti + sha256 (fra `assets/quarantine/<pakke>/manifest.json`).

Hver række har et anker (`#unit-b01`, `#stage-heart` …). `docs/ASSET_LEDGER.csv` → kolonnerne `candidate` og `asset_map_ref`, og `docs/ANIMATION_LEDGER.csv` → `planned_clip` og `asset_map_ref` peger hertil.

---

## 0. Købsliste / tjekliste

**Minimum** (giver alle 51 slots en rigtig kandidat eller en bevidst procedural løsning):

- [ ] **Synty POLYGON Nature** — etager, stamme, rødder, svampe, sten, baggrundsklipper, mutationer (M01–M03), Svampevæg (S03), attachments (bark, grene, svampehatte). *Den vigtigste pakke.*
- [ ] **Synty POLYGON Dark Fantasy** — askefjender E01–E05, Askekronen (E06), tunge humanoide baser (Barkvogter, Gammel Eg, Sporekolos), Nattehætte.
- [ ] **Synty POLYGON Fantasy Characters** — små/mellem humanoide baser: Sporevismand, Barkskjold, Saftbærer, Mycelievogter; stave, skjolde.
- [ ] **PolyPerfect Low Poly Animated Animals** — Tornhjort (B04, firbenet hjort med egne klip). Uden den: B04 forbliver proxy (det er tilladt).
- [ ] **Mixamo** (gratis, Adobe-konto) — 9 klip, ét pr. tilstand (§2.2). Uden dem: procedural bevægelse (tilladt, men "stift").

**Nice-to-have** (bedre match til REF-billederne, ikke nødvendigt for LR-13):

- [ ] **Synty POLYGON Elven Realm** — krystaller, gyldne blomster (Kronen, M03), hjertets grenvugge, lanterner med elverstil.
- [ ] **Synty POLYGON Fantasy Kingdom** — ravlanterner, træskjolde, træplanker.
- [ ] **Synty POLYGON Dungeons** — turkise krystaller, kulblokke (Kulskjold), lanterner.
- [ ] **Synty POLYGON Fantasy Rivals** — monster-/kæmpefigurer (alternativ til Dark Fantasy for golem, imp, boss).
- [ ] **Synty POLYGON Particle FX** — kun **teksturer** (røg, gnister, blade) til vores egne Godot-partikler; Unity-partikelsystemer konverteres ikke.
- [ ] **Synty ANIMATION-pakker** *(usikkert produktnavn — fx "Animation – Base Locomotion", "Animation – Sword Combat", "Animation – Spellcasting"; tjek Synty Store)* — alternativ til Mixamo med Synty-skelet; bruges kun hvis du allerede ejer dem.
- [ ] **PolyPerfect Low Poly Ultimate Pack** — små stubbe/svampe/sten som alternativer (B02, S02, props).

**Køb ikke for LR-13:** flere end 3 Synty-pakker til figurer. Biblen: konsistens frem for at vise alle pakker. Én materialestil = pakkens atlas + vores emissive farver (§1.4).

---

## 1. Fælles regler

### 1.1 Skala (mål fra `docs/ASSET_LEDGER.csv` → `scale_m`, = `asset_slots.json` → `height`)

| Gruppe | Mål (m) | Wrapperens `fit` |
|---|---|---|
| Små væsner/fjender | 0,93 (Sporeunge) · 0,95 (Askeling) · 1,13 (Kulskjold) · 1,22 (Rodspire) · 1,29 (Saftbærer) · 1,39 (Nattehætte) | `height` |
| Mellem | 1,54 (Mycelievogter, Sodbærer) · 1,56 (Svampevæg) · 1,57 (Barkskjold) · 1,68 (Glødjæger) · 1,73 (Sporevismand) | `height` |
| Store | 2,03 (Stenbrud) · 2,29 (Tornhjort) · 2,33 (Sporekolos) · 2,56 (Gammel Eg) · 2,60 (Barkvogter) | `height` |
| Boss | 3,41 (Askekronen) | `height` |
| Etager | 0,20 tyk, 11,6 m bred overflade på y=0, dybde 3,2 | `footprint`, `align: top` |
| Stamme / hjerte / baggrund | 4,5 pr. segment · 2,0 · 30 (z < −15) | `height` / `height` / `natural` |
| Props · mutationer | lanterne 1,25 · svampe 0,75 · krystal 1,0 · rodbue 1,7 · sten 0,55 · mutationer 1,0 | `natural` (cm→m rettes automatisk) |

Synty-FBX er normalt i cm (×0,01 rettes af byggeren). Figurer vender typisk +Z ved import → `rotation_y: 180` er standard i `synty_choices.json`; tjek pilen "front = −Z" i RigLab.

### 1.2 Rigfamilier

| Familie | Slots | Kilde til klip | Note |
|---|---|---|---|
| `humanoid` | B01–B03, B05, B06, S01, S02, S04–S06, E01–E06 | Mixamo (eller Synty ANIMATION) via ét fælles bibliotek `art/animations/humanoid.res` | Synty-knoglenavne (`Hips`, `Spine_01`, `Clavicle_L`, `Shoulder_L`, `Elbow_L` …) og Mixamo (`mixamorig:Hips`, `LeftArm`, `LeftUpLeg` …) mappes automatisk |
| `quadruped` | B04 | Dyrets **egne** PolyPerfect-klip | **Aldrig** humanoid retarget (biblen) |
| `static` | S03, `stage.heart` | Ingen — `UnitAnimator` procedural | Ingen knogler |

### 1.3 Retarget i Godot 4.5 (det byggeren gør — og hvad du ser efter)

1. Byggeren (`tools/synty/humanoid_bone_mapper.gd`) skriver et `BoneMap` med profilen **`SkeletonProfileHumanoid`** til `art/rigs/<pakke>__<fil>.bonemap.tres` og sætter det i modellens `.import` (`_subresources → nodes → PATH:<Skeleton3D> → retarget/bone_map`). Skelettet omdøbes ved import til `GeneralSkeleton`; så kan ét Mixamo-sæt spille på alle humanoider.
2. Manuelt (hvis rapporten siger `bone map missing: …`): dobbeltklik FBX → **Advanced Import Settings** → vælg `Skeleton3D` → **Retarget → Bone Map** → *New BoneMap* → Profile = *SkeletonProfileHumanoid* → ret røde felter → *Reimport*.
3. Rest-pose: Mixamo er T-pose; nogle Synty-figurer importeres i A-pose *(verificér)*. Ser arme/ben skæve ud efter retarget, så slå **Rest Fixer → Fix Silhouette** til (samme sted) og genimportér. *Overwrite Axis* og *Normalize Position Tracks* skal være til (Godots standard i 4.5 — verificér).
4. Over 4 manglende kerneknogler → byggeren nægter retarget og bruger modellens egne klip (RigLab: "slot expects a humanoid but the rig has no humanoid bone map"). Vælg en anden model.
5. Root motion: byggeren fjerner hoftens vandrette fremdrift; men download alligevel gang med **In Place**.
6. Første humanoide FBX: kør `model_probe.gd` på den før godkendelse (`docs/SYNTY_INTEGRATION.md` §6b) — retarget af en *rigtig* humanoid FBX er endnu ikke bevist.

### 1.4 Materialer og palette (matcher REF_01–05)

Byggeren laver ét atlas-materiale pr. pakke (`art/materials/<pakke>_atlas.tres`; Synty-atlas hedder typisk `Polygon<Pakke>_Texture_01*.png` — kandidat). Identiteten kommer fra de emissive farver i `data/art/palette.json`:

| Rolle | Hex (palette-nøgle) | Hvor | REF |
|---|---|---|---|
| Ravlys (øjne, døråbning, lanterner) | `#ffb238` amber · `#e88a1f` amber_soft | Barkvogterens øjne, stammens dør, lanterner, Saftbærerens kugle | REF_01, 02, 03 |
| Bark / træ / mos | `#6b4a2f` bark · `#3f2a1b` bark_dark · `#5f7f2e` moss | Bark-væsner, stamme, etagekanter (hængende mos) | REF_01, 05 |
| Violette svampe | `#7a4cd6` cap_violet · `#ece4f5` cap_white · `#4a2f6e` spore_body | Sporevismandens hat (hvid-violet), Sporeunger, svampeprops | REF_02, 05 |
| Turkis liv | `#3ff2d6` turquoise · `#22b8a6` turquoise_soft | Hjertet, stavens spids, Mycelievogterens lanterne, M02-årer | REF_01, 05 |
| Aske | `#1b1a1d` ash_black · `#2b2624` charcoal · `#4a464a` ash_grey | Alle fjender: mørk silhuet, ingen farvet tøjtekstur | REF_01, 03 |
| Glød | `#ff7a1f` ember · `#ffd060` ember_hot · `#e8401c` ember_red | Fjendeøjne, revner, Askekronens kerne | REF_03 |
| Gift / heal | `#9be04e` poison · `#b26cf0` poison_violet · `#7dffb0` heal | FX | REF_03 |

Regler: fjenderne må **ikke** få pakkens farvede tøj — brug en mørk omfarvning (ét `ash`-materiale + emissive øjne/revner). REF_01 viser violette øjne på fjenderne; proxyerne bruger **ember-orange** (`palette.json`), så violet forbeholdes Spore-siden — ret i `palette.json`, hvis du foretrækker REF-violet. Hat, stav og krystaller må aldrig dække enhedstal (REF_05-guiden).

---

## 2. Animation

### 2.1 Spilroller → tilstande (hvad kampen faktisk afspiller)

| Spilrolle | Tilstand | Udløses af (`scripts/presentation/battle_presenter.gd`) | Prioritet |
|---|---|---|---|
| Hvile | `idle` (loop) | altid | **must** |
| Spawn (allieret indsat) | `summon` | `unit_inserted` | **must** |
| Fjende ankommer / klatrer | `move` (loop, In Place) | `enemy_spawned`, `enemy_climbed` | **must** |
| Angreb (Bark + fjender) | `attack` (kontakt 0,30 s) | `attack` | **must** |
| Angreb/evne (alle Spore-allierede) | `cast` (kontakt 0,38 s) | `attack` når kort-id starter med `S` | **must** |
| Ramt / gift-tik | `hit` | `damage`, `thorns`, `poison_tick` | **must** |
| Død | `death` | `death` | **must** |
| Sejr | `victory` | menu- og epilog-dioramaer (ikke i kampen) | nice |
| Forsvar | `defend` | kun galleri/RigLab i dag | nice |

Bemærk: **alle** Spore-væsner (også Sporeunge, Nattehætte, Sporekolos) spiller `cast` ved angreb, fordi præsentationen sender en sporebolt. Med det fælles bibliotek får Nattehætten derfor magiklippet. Vil du have dolkestik dér, er det en lille præsentationsændring (uden for asset-arbejdet) — notér det, hvis det generer.

### 2.2 Minimum: ét fælles Mixamo-sæt (9 filer) — det pipelinen bygger i dag

`match.py` vælger **én fil pr. tilstand** for hele `humanoid`-familien (første filnavn i alfabetisk orden, der indeholder et nøgleord fra `data/art/animation_sets.json → keywords`). Læg derfor kun disse 9 filer i mappen første gang:

| Tilstand | Mixamo-søgning / filnavn | In Place | Loop | Kontakt | Kommentar |
|---|---|---|---|---|---|
| idle | `Breathing Idle.fbx` | — | ja | — | rolig, passer både tunge og små |
| summon | `Standing Up.fbx` | — | nej | — | "vokser op" fra gulvet; alternativ `Getting Up` |
| attack | `Punching.fbx` | ja | nej | 0,30 s | alternativ `Sword And Shield Slash` til Barkskjold/Glødjæger |
| cast | `Standing 1H Magic Attack 01.fbx` | ja | nej | 0,38 s | sporebolt udløses ved kontakt |
| hit | `Hit Reaction.fbx` | ja | nej | — | kort; alternativ `Standing React Small From Front` |
| death | `Dying.fbx` | — | nej | — | alternativ `Standing Death Backward 01` |
| defend | `Standing Block Idle.fbx` | — | nej | — | nice-to-have |
| victory | `Victory.fbx` | — | nej | — | alternativ `Cheering` |
| move | `Walking.fbx` | **ja** | ja | — | alternativ `Standing Walk Forward` |

**Mixamo-download (pr. klip):** Format **FBX Binary (.fbx)** · Skin **Without Skin** (én enkelt fil "With Skin" som reference er nok) · Frames per Second **30** · Keyframe Reduction **none** · **In Place** til (vises kun på gang-/løbeklip) · Trim/Overdrive urørt · vælg samme Mixamo-karakter (fx *Y Bot*) til alle klip. Filnavnet bliver normalt klippets navn; hedder filen noget andet, så omdøb den til navnet i tabellen (ellers matcher `match.py` ikke — `tools/synty/doctor.py` advarer). Læg filerne i én mappe, fx `D:/LASTROOT_vendor/Mixamo/`, og kør `unpack.py` på mappen (pakkenavnet bliver mappens navn; behold "Mixamo" i navnet).

### 2.3 Nice-to-have: varianter pr. vægtklasse

Følgende er **ikke** bygget i pipelinen endnu (ét humanoid-bibliotek for alle). Det kræver en lille ændring i `tools/synty/build_wrappers.gd`/`slot_wrapper_builder.gd`: en `"anim_family"` pr. valg (fx `humanoid_heavy`) → eget bibliotek. Notér ønsket under LR-18 i stedet for at hente alle klip nu.

| Vægtklasse | Slots | idle | attack | hit | death | move | victory | summon |
|---|---|---|---|---|---|---|---|---|
| tung | B01, B06, S06, E04, E05, E06 | Mutant Breathing Idle | Mutant Punch / Mutant Swiping | Mutant Hit Reaction | Mutant Dying | Mutant Walking | Mutant Roaring | Mutant Jumping |
| lille | B02, B05, S02, E01 | Happy Idle | Punching / Goblin Attack *(usikkert navn)* | Hit Reaction | Dying | Sneak Walk | Jumping | Standing Up |
| skjold | B03, E02 | Breathing Idle | Sword And Shield Bash / Slash | Sword And Shield Impact *(usikkert navn)* | Dying | Walking | Victory | Standing Up |
| snigmorder | S04 | Sneaking Idle *(usikkert navn)* | Stabbing | Hit Reaction | Dying | Walking | Victory | Standing Up |
| spyd | E03 | Breathing Idle | Standing Melee Attack Downward / Spear Stab *(usikkert)* | Hit Reaction | Dying | Walking | — | Standing Up |
| magiker | S01, S05 | Breathing Idle | (cast) Standing 2H Magic Attack 01 · Magic Spell Casting | Hit Reaction | Standing Death Backward 01 | Walking | Victory | Standing Up |

**Synty ANIMATION-alternativ:** hvis du ejer Synty-animationspakker, ligger klippene på Synty-skelettet (`A_*`-filer — kandidat). De mappes på samme måde (`SkeletonProfileHumanoid`); læg dem i en mappe med "Animation" i stien, så `match.py` ser dem som klip. Bland ikke Synty- og Mixamo-klip i første omgang.

**PolyPerfect-alternativ:** PolyPerfects animerede figurer/dyr har egne klip (`Idle`, `Attack`, `Walk`, `Death`, `Hit` — navne varierer, fx `Idle_A`, `Attack_1`). Bruges kun til B04 (og evt. som stand-in for små væsner); sæt `"clips": {"idle": "<navn>", …}` i `synty_choices.json`, hvis nøgleordene ikke rammer.

---

## 3. Træet (TreeStage) og hjertet

Placering og mål: `docs/SCENE_ASSEMBLY.md`. Princip (REF_05-guiden): form først, lys bagefter, små props til sidst.

| Slot | Hvad | Primær pakke · prefab-mønster (kandidat — verificér i pakken) | PolyPerfect-alternativ | Mål / fit | Materiale / noter | REF |
|---|---|---|---|---|---|---|
| <a id="stage-floor-roots"></a>`stage.floor_roots` | Rødderne (nederste etage) | POLYGON Nature · `SM_Env_Rock_Flat_*`, `SM_Env_Ground_*`, `SM_Env_Tree_Root_*` (rødder hænger under) | Ultimate Pack: flade klippeplader | 11,6 × 3,2 m, top y=0 · `footprint` | Mørk sten + mos; hængende rødder; props kun på bagkant | REF_01, REF_05 |
| <a id="stage-floor-trunk"></a>`stage.floor_trunk` | Stammen (midteretage) | POLYGON Nature · `SM_Env_Rock_Flat_*`, `SM_Env_Path_*` (stenfliser) | — | som ovenfor | Violette svampe på bagkanten | REF_01, REF_05 |
| <a id="stage-floor-crown"></a>`stage.floor_crown` | Kronen (øverste etage) | POLYGON Nature · `SM_Env_Rock_Flat_*`, `SM_Env_Tree_Branch_*`; Elven Realm for kant | — | som ovenfor | Krystaller + gyldne blomster på bagkant | REF_05 |
| <a id="stage-trunk"></a>`stage.trunk` | Stammesegment bag etagerne | POLYGON Nature · `SM_Env_Tree_Giant_*`, `SM_Env_Tree_Trunk_*`, `SM_Env_Tree_Dead_*` (skaleret); dør: `SM_Bld_*Door*` | Ultimate Pack: store træer | 4,5 m pr. segment, z ≈ −2,9 · `height` | Rav-døråbning mod kamera (emissive `amber`); altid bag enheder | REF_01, REF_03 |
| <a id="stage-heart"></a>`stage.heart` | Træets hjerte | Behold proceduralt facetteret hjerte; ellers Elven Realm / Dungeons · `SM_Prop_Crystal_*`, `*Gem*`, `*Heart*` + grenvugge af `SM_Env_Tree_Branch_*` | — | ~2,0 m · `height` · rig `static` | Turkis emissive `#3ff2d6` + egen OmniLight; højeste visuelle prioritet | REF_01, REF_02, REF_05 |
| <a id="stage-backdrop"></a>`stage.backdrop` | Flydende øer, spir, måne | POLYGON Nature · `SM_Env_Rock_Large_*`, `SM_Env_Cliff_*`, `SM_Env_Rock_Spire_*`; Elven Realm `*Floating*Island*` | — | z < −15 · `natural` | Lav detalje, violet dis (`haze`), ingen skygger nødvendige | REF_02, REF_04 |

Animation: `stage.heart` → `idle`/`hit` procedural (`UnitAnimator`). Etager/stamme/baggrund har ingen animation.

---

## 4. Champions

| Slot | Kort | Primær pakke · basismodel (kandidat) | Attachments (kandidat) | PolyPerfect-alt. | Rig · mål | Materiale | REF |
|---|---|---|---|---|---|---|---|
| <a id="unit-b01"></a>`unit.B01` | **Barkvogteren** (B01, champion, 8 panser) | POLYGON Dark Fantasy · `SK_Chr_*Golem*`, `SK_Chr_*Giant*`; alt. Fantasy Rivals `*Rock*Giant*`, `*Treant*` | Barkplader/sten: POLYGON Nature `SM_Env_Rock_*`, `SM_Env_Log_*`/`*Bark*`; planke-skjold `SM_Wep_Shield_*Wood*` (Fantasy Kingdom) | — | humanoid · 2,60 m, 2 pladser | Bark/sten-atlas, mos, **rav-emissive øjne** | REF_02, REF_03 |
| <a id="unit-s01"></a>`unit.S01` | **Sporevismanden** (S01, champion, Gift 2) | Fantasy Characters · `SK_Chr_*Wizard*`, `SK_Chr_*Druid*`; alt. Elven Realm `SK_Chr_*Druid*` | Kæmpe svampehat: POLYGON Nature `SM_Env_Mushroom_*` (skaleret ×3–4, hvid-violet omfarvning) på hovedknoglen; stav `SM_Wep_Staff_*` med turkis emissive spids | — | humanoid (cast) · 1,73 m, 2 pladser | Kappe violet/hvid (`cap_violet`, `cap_white`), skæg `beard` | REF_02, REF_03 |

Animation, champions (fælles sæt §2.2; varianter §2.3):

| Tilstand | B01 Barkvogter | S01 Sporevismand |
|---|---|---|
| idle | Breathing Idle (nice: Mutant Breathing Idle) | Breathing Idle |
| summon | Standing Up (nice: Mutant Jumping) | Standing Up |
| attack / cast | attack: Punching (nice: Mutant Punch; Sword And Shield Bash hvis skjold) | cast: Standing 1H Magic Attack 01 (nice: Standing 2H Magic Attack 01) |
| hit | Hit Reaction (nice: Mutant Hit Reaction) | Hit Reaction |
| death | Dying (nice: Mutant Dying) | Dying |
| defend | Standing Block Idle | Standing Block Idle |
| victory | Victory (nice: Mutant Roaring) | Victory |
| move | Walking (nice: Mutant Walking) | Walking |

Godkend champions først (LR-13 kræver "begge champions"): hat og stav skal kunne læses ved kampkameraet; Barkvogteren skal være tydeligt tungere end alt andet på sin etage undtagen Gammel Eg.

---

## 5. Allierede væsner (kort med en enhed)

Kun B02–B06 og S02–S06 er væsner; B07–B12 og S07–S12 er besværgelser (se §8 FX). Animation = fælles sæt §2.2 medmindre andet står; "vægt" henviser til §2.3.

| Slot | Kort | Primær pakke · basismodel (kandidat) | Attachments (kandidat) | PolyPerfect-alt. | Rig · mål · vægt | Animation-afvigelser | Materiale | REF |
|---|---|---|---|---|---|---|---|---|
| <a id="unit-b02"></a>`unit.B02` | Rodspire (B02) | POLYGON Nature `*Sapling*`/`*Stump*` hvis rigget; ellers Fantasy Characters `SK_Chr_*Goblin*`/barnestørrelse | Bladkrone + rodfødder: `SM_Env_Plant_*`, `SM_Env_Tree_Root_*` | Ultimate Pack: stub-/sprout-figur (verificér om rigget) | humanoid · 1,22 m · lille | — | bark_light + leaf_bright | REF_01 |
| <a id="unit-b03"></a>`unit.B03` | Barkskjold (B03, 6 panser) | Fantasy Kingdom / Fantasy Characters `SK_Chr_*Knight*` (lav, bred) | Højt planke-tårnskjold `SM_Wep_Shield_*Wood*`, `*Shield*Tower*` | — | humanoid · 1,57 m · skjold | nice: Sword And Shield Bash/Block | wood_plank, bark | REF_01, REF_03 |
| <a id="unit-b04"></a>`unit.B04` | Tornhjort (B04, Torne 2) | **PolyPerfect Low Poly Animated Animals** `*Deer*`/`*Stag*` (alt. `*Elk*`, `*Moose*`) | Torngevir af POLYGON Nature `SM_Env_Tree_Branch_*` på hovedknoglen | (er selv PolyPerfect) | **quadruped** · 2,29 m | Dyrets egne klip: idle `Idle*`, attack `Attack*`, hit `Hit*` (mangler ofte → procedural), death `Death*`, move `Walk*`; summon procedural. Ingen retarget | bark-omfarvning, thorns-grøn spidser | REF_01 |
| <a id="unit-b05"></a>`unit.B05` | Saftbærer (B05, heal 3) | Fantasy Characters `SK_Chr_*Dwarf*` (rund, kort) | Glødende ravkugle/krukke `*Jar*`, `*Honey*`, `SM_Prop_Lantern_*` | Ultimate Pack: krukke-prop | humanoid · 1,29 m · lille | — | amber-emissive kugle | REF_01 |
| <a id="unit-b06"></a>`unit.B06` | Gammel Eg (B06, 3 pladser) | Dark Fantasy / Nature `*Treant*`, `*Tree*Monster*`; ellers `SK_Chr_*Giant*` | Lav, bred egekrone `SM_Env_Tree_Oak_*` (skær toppen ned, så tal ses) | Ultimate Pack: egetræ som krone | humanoid · 2,56 m · tung | nice: Mutant-sættet | bark_dark, moss, leaf | REF_01, REF_04 |
| <a id="unit-s02"></a>`unit.S02` | Sporeunge (S02, Gift 1) | POLYGON Nature `*Mushroom*` hvis rigget; ellers `SK_Chr_*Goblin*`/`*Imp*` | Svampehat + selvlysende antenne-sporer `SM_Env_Mushroom_*` | Ultimate Pack: svampefigur | humanoid · 0,93 m · lille | angriber med `cast` (§2.1) | cap_white/cap_violet, turkis prikker | REF_01, REF_02 |
| <a id="unit-s03"></a>`unit.S03` | Svampevæg (S03, Vækst 2) | POLYGON Nature: klynge `SM_Env_Mushroom_*` + `*Shelf*`/`*Fungus*` på en sten | — | Ultimate Pack: svampe | **static** · 1,56 m | procedural (ingen rig) | cap_violet + emissive lameller | REF_05 |
| <a id="unit-s04"></a>`unit.S04` | Nattehætte (S04, +3 mod forgiftet) | Dark Fantasy / Fantasy Characters `SK_Chr_*Assassin*`, `SK_Chr_*Rogue*` | Spids mørk hætte (svampehat, indigo) + tornedolke `SM_Wep_Dagger_*` | — | humanoid · 1,39 m · snigmorder | angriber med `cast` (§2.1); nice: Stabbing | spore_skin, cap_violet_dark | REF_05 |
| <a id="unit-s05"></a>`unit.S05` | Mycelievogter (S05, Vækst 1 til etagen) | Elven Realm / Fantasy Characters `SK_Chr_*Druid*`, `SK_Chr_*Monk*` | Turkis sporelanterne `SM_Prop_Lantern_*`, svampehat | — | humanoid (cast) · 1,54 m · magiker | cast: Standing 1H Magic Attack 01 (nice: Magic Spell Casting) | turquoise-emissive lanterne | REF_05 |
| <a id="unit-s06"></a>`unit.S06` | Sporekolos (S06, Gift 3 ved død) | Dark Fantasy `SK_Chr_*Giant*`, `SK_Chr_*Ogre*`, `*Troll*` | Meget stor svampehat `SM_Env_Mushroom_Large_*` + glødende sporesække | — | humanoid · 2,33 m · tung | angriber med `cast`; nice: Mutant-sættet | cap_violet, poison_violet sække | REF_05 |

---

## 6. Askefjender

Biblen: 2–3 humanoide rigs genbruges (A lille · B kompakt · C tung) med forkullet omfarvning, ember-øjne og egne attachments. Visuelle varianter giver aldrig nye evner (tallene står i kataloget).

| Slot | Fjende | Primær pakke · basismodel (kandidat) | Attachments (kandidat) | PolyPerfect-alt. | Rig · mål · familie | Animation-afvigelser | Materiale | REF |
|---|---|---|---|---|---|---|---|---|
| <a id="enemy-e01"></a>`enemy.E01` | Askeling (2/5) | Dark Fantasy `SK_Chr_*Imp*`, `SK_Chr_*Goblin*`; alt. Dungeons `*Ghoul*` | Lang hale (egen mesh), krum ryg | — | humanoid · 0,95 m · A (lille) · spillehastighed 1,3 | nice: lille-sættet (Sneak Walk) | ash_black + ember-øjne | REF_01, REF_03 |
| <a id="enemy-e02"></a>`enemy.E02` | Kulskjold (3/9, 4 panser) | Dark Fantasy / Dungeons `SK_Chr_*Skeleton*`, `SK_Chr_*Golem*` (lav, bred) | Pladeskjold med glødende kant `SM_Wep_Shield_*`; kulblokke | — | humanoid · 1,13 m · B (kompakt) | nice: skjold-sættet | charcoal + ember-kant | REF_01 |
| <a id="enemy-e03"></a>`enemy.E03` | Glødjæger (5/7) | Dark Fantasy / Fantasy Rivals `SK_Chr_*Hunter*`, `SK_Chr_*Demon*` | Ember-spyd `SM_Wep_Spear_*`, pigge; foroverlænet | — | humanoid · 1,68 m · A/B | nice: spyd-sættet | ash_grey + ember_hot spids | REF_01, REF_03 |
| <a id="enemy-e04"></a>`enemy.E04` | Sodbærer (2/12) | Dark Fantasy / Dungeons `SK_Chr_*Fat*`, `SK_Chr_*Ogre*` | Sodsæk på ryggen, skorstens-ventiler | — | humanoid · 1,54 m · B (rund) | nice: tung-sættet | charcoal + ember-mave | REF_03 |
| <a id="enemy-e05"></a>`enemy.E05` | Stenbrud (6/16, 6 panser) | Dark Fantasy / Fantasy Rivals `SK_Chr_*Golem*`, `SK_Chr_*Brute*` | Basaltplader, kæmpe næver | — | humanoid · 2,03 m · C (tung) | nice: tung-sættet | stone_dark + ember-revner | REF_01 |

### Boss

| Slot | Boss | Primær pakke · basismodel (kandidat) | Attachments | Rig · mål | Animation | Materiale | REF |
|---|---|---|---|---|---|---|---|
| <a id="enemy-e06"></a>`enemy.E06` | **Askekronen** (8/60, 8 panser, ankomst tur 5, eskalerer fra tur 10) | Dark Fantasy `SK_Chr_*King*`, `SK_Chr_*Lich*`, `SK_Chr_*Giant*`; alt. Fantasy Rivals | Egen forkullet krone af grene og sten (POLYGON Nature `SM_Env_Tree_Branch_*` + `SM_Env_Rock_*`, sort omfarvning) på hovedknoglen + emissive kerne i brystet | humanoid · **3,41 m** · familie C skaleret | fælles sæt + victory (nederlags-epilog); nice: Mutant-sættet (Mutant Roaring ved ankomst) | ash_black, ember/ember_red kerne; klart ansigt | REF_01 (silhuet), REF_03 |

Bossen må ikke skjule sit eget hp-/panser-badge: hold kronen under 3,6 m (`head_height`).

---

## 7. Props og mutationer

Props står kun på bagkanten (aldrig foran enhedstal). Mutationer ændrer kun visuals på samme scene — aldrig kollision eller klikmål.

| Slot | Hvad | Primær pakke · mønster (kandidat) | PolyPerfect-alt. | Mål | Materiale | REF |
|---|---|---|---|---|---|---|
| <a id="prop-lantern"></a>`prop.lantern` | Hængende ravlanterne | Fantasy Kingdom `SM_Prop_Lantern_*`, `SM_Prop_Lamp_*`; alt. Elven Realm / Dungeons | Ultimate Pack: lanterne | 1,25 m | amber-emissive glas | REF_01, REF_05 |
| <a id="prop-mushroom-cluster"></a>`prop.mushroom_cluster` | Lysende svampe | POLYGON Nature `SM_Env_Mushroom_*`, `*Mushroom*Group*` | Ultimate Pack: svampe | 0,75 m | cap_violet + emissive lameller, turkis prikker | REF_02, REF_05 |
| <a id="prop-crystal"></a>`prop.crystal` | Turkis krystal | Dungeons `SM_Prop_Crystal_*`; alt. Elven Realm `SM_Env_Crystal_*` | — | 1,0 m | turquoise-emissive | REF_03, REF_05 |
| <a id="prop-root-arch"></a>`prop.root_arch` | Rodbue | POLYGON Nature `SM_Env_Tree_Root_*`, `SM_Env_Rock_Arch_*` | — | 1,7 m bred | bark + mos | REF_02 |
| <a id="prop-rock"></a>`prop.rock` | Mosklædt sten | POLYGON Nature `SM_Env_Rock_0*`, `SM_Env_Rock_Small_*` | Ultimate Pack: sten | 0,55 m | stone + moss | REF_05 |
| <a id="mutation-m01"></a>`mutation.M01` | Dybe rødder (+1 plads på Rødderne) | POLYGON Nature `SM_Env_Tree_Root_*` ekstra rødder over bagkant og hængende under | — | 1,0 (etage-ramme) | bark_dark | REF_05 |
| <a id="mutation-m02"></a>`mutation.M02` | Stærk stamme (+1 angreb på Stammen) | POLYGON Nature/Elven Realm `*Vine*`, `*Ring*` som barkbånd om stammen | — | 1,0 (stamme-ramme) | turkise årer (emissive) | REF_05 |
| <a id="mutation-m03"></a>`mutation.M03` | Mild krone (heal 2 på Kronen) | Elven Realm/Nature `*Blossom*`, `*Flower*` langs Kronens bagkant | — | 1,0 (etage-ramme) | blossom, blossom_gold | REF_05 |
| <a id="mutation-m04"></a>`mutation.M04` | Stort hjerte (+15 hjerteliv) | Godot: større glorie, ekstra skår, stærkere lys; Particle FX kun teksturer `FX_*Glow*` | — | 1,0 (hjerte-ramme) | turquoise | REF_01, REF_05 |

---

## 8. Effekter (FX) og besværgelser

Unity-partikelsystemer konverteres ikke. Alle FX bygges i Godot (`CPUParticles3D`, `scripts/runtime/visual/fx_builder.gd`); fra **POLYGON Particle FX** genbruges kun teksturer (røg, gnist, blad, glød — kandidat `FX_*`/`*_Texture*`). Ingen animation; ingen rig.

| Slot | Effekt | Udløses af | Kort / evne | Tekstur-kandidat | Farve | REF |
|---|---|---|---|---|---|---|
| <a id="fx-poison"></a>`fx.poison` | Giftbobler (loop) | `poison_tick` | S01, S02, S06, S07, S08, S11, S12 | `FX_*Poison*`, `FX_*Smoke*` | poison, poison_violet | REF_03 |
| <a id="fx-heal"></a>`fx.heal` | Gnister + ring | `heal` | B05, B11, S09, M03, R05 | `FX_*Heal*`, `FX_*Spark*` | heal, turquoise | — |
| <a id="fx-armor"></a>`fx.armor` | Facetteret skal | `armor_gained` | B01, B03, B08, R01 | `FX_*Magic*` | armor | — |
| <a id="fx-thorns"></a>`fx.thorns` | Tornering | `thorns` | B04 | blad/torn-tekstur | thorns | — |
| <a id="fx-growth"></a>`fx.growth` | Stigende blade | Vækst-status (loop; ingen egen afspilning i presenteren i dag) | S03, S05, S09 | `FX_*Leaf*` | leaf_bright | REF_05 |
| <a id="fx-spore-bolt"></a>`fx.spore_bolt` | Turkis kugle med spor | Spore-angreb (`cast`-kontakt) | alle S-væsner | `FX_*Magic*`, `FX_*Glow*` | turquoise | REF_03 |
| <a id="fx-bark-hit"></a>`fx.bark_hit` | Træsplinter + gnister | `damage` | B07, B09, S10, alle angreb | `FX_*Hit*`, `FX_*Spark*` | amber, bark_light | REF_03 |
| <a id="fx-ash-death"></a>`fx.ash_death` | Askesky + gløder | fjende-`death` | — | `FX_*Smoke*` | ash_grey, ember | REF_03 |
| <a id="fx-heart-pulse"></a>`fx.heart_pulse` | Turkis ringpuls (loop) | altid | M04 større | `FX_*Glow*` | turquoise | REF_01, REF_05 |
| <a id="fx-heart-damage"></a>`fx.heart_damage` | Skår + ring | `heart_damaged` | — | `FX_*Hit*` | ember_red, turquoise | — |
| <a id="fx-summon-bark"></a>`fx.summon_bark` | Blade og bark fra gulvet | Bark-`summon` | B02–B06 | `FX_*Leaf*`, `FX_*Dust*` | leaf, bark | — |
| <a id="fx-summon-spore"></a>`fx.summon_spore` | Violette sporer | Spore-`summon`, S01 `victory` | S02–S06 | `FX_*Magic*` | cap_violet, turquoise | REF_02 |
| <a id="fx-ash-puff"></a>`fx.ash_puff` | Askepuf | fjendens første optræden | — | `FX_*Smoke*` | ash_light, ember | — |
| <a id="fx-wilt"></a>`fx.wilt` | Faldende blade | Bark-`death` | — | `FX_*Leaf*` | leaf | — |
| <a id="fx-wilt-spore"></a>`fx.wilt_spore` | Faldende hatteflager | Spore-`death` | — | — | cap_pale | — |
| <a id="fx-ember-trail"></a>`fx.ember_trail` | Glødespor | fjende-`attack` | — | `FX_*Spark*`, `FX_*Fire*` | ember | REF_03 |
| <a id="fx-ring"></a>`fx.ring` | Målring ved fødder | målvalg / fare | alle kort med mål | — (procedural) | turquoise / amber / ember_red | REF_03 |
| <a id="fx-floor-target"></a>`fx.floor_target` | Etagestribe | etagemål | B09, B11, S08 | — (procedural) | turquoise | REF_01 |

Besværgelser uden enhed: B07 Rodslag → `fx.bark_hit` · B08 Barkhud → `fx.armor` · B09 Rodnet → `fx.floor_target` + `fx.bark_hit` · B10 Grenløft → (flytning, ingen egen FX) · B11 Saftflod → `fx.floor_target` + `fx.heal` · B12 Sidste Kvist → (fjern, ingen egen FX) · S07 Giftpust → `fx.poison` · S08 Sporetåge → `fx.floor_target` + `fx.poison` · S09 Livstråd → `fx.heal` + `fx.growth` · S10 Nedbrydning → `fx.bark_hit` (panserfjernelse har ingen egen FX i dag) · S11 Blomstring → `fx.poison` · S12 Sporeregn → `fx.poison` på alle etager.

---

## 9. Rækkefølge for LR-13 (ét asset ad gangen)

1. `stage.floor_roots` → godkend → `stage.floor_trunk` + `stage.floor_crown` (samme mønster) → `stage.trunk`. Sammenlign med REF_01/REF_05.
2. `unit.B01` og `unit.S01` (begge champions) + Mixamo-sættet → RigLab + galleri "gate".
3. To normale væsner: `unit.B02`, `unit.S02`. To fjender: `enemy.E01`, `enemy.E02` (= biblens line-up og `docs/PRODUCTION_PLAN.md`).
4. Resten af fjenderne, bossen, så B03–B06/S03–S06, props, mutationer. FX sidst (kun teksturer).

Hvert trin: én ændring i `data/art/synty_choices.json` → `tools/synty/build.sh` → se efter → `review_status` i `docs/ASSET_LEDGER.csv`. Detaljer og tjekbokse: `docs/HOMECOMING.md`.
