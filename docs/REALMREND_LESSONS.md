# Lærdomme fra Realmrend → LASTROOT (Synty · Godot · Blender)

*Skrevet 22.10.2026 ud fra ejerens tidligere projekt REALMREND: Crowns at War, som brugte de RIGTIGE Synty-pakker i Godot 4.7.1 (august 2026). Kilder citeres som `realmrend:<sti>` (repoet `sebastianlistfeirup/realmrend-crowns-at-war`) og `genesisark:<sti>`. Det bindende valg pr. slot står i `data/art/synty_selection.json`; dette dokument forklarer hvorfor.*

**Kort sagt:** Statiske Synty-modeller og deres atlas virker i Godot uden besvær. Figurer og animation er det svære: to forskellige rig-navngivninger, forskellige hvile-poser, og figur-prefabs i Godot-buildet, der ikke deformerede. Lastroots pipeline (FBX → Godots egen import → BoneMap-retarget, `docs/SYNTY_INTEGRATION.md` §6c) undgår de fleste fælder, men skal stadig afprøves på én rigtig figur først.

---

## 1. Hvad ejeren faktisk har (verificeret)

Kilde: `realmrend:docs/ledgers/asset_ledger.csv` (16 rækker SYN-01..16, alle med bytes + sha256), `realmrend:docs/reviews/A07_synty_licence_summary.md`.

| Gruppe | Arkiver (præcise filnavne) |
|---|---|
| ANIMATION (6) | `ANIMATION_Base_Locomotion_SourceFiles_v3.zip`, `ANIMATION_Bow_Combat_SourceFiles_v1.zip`, `ANIMATION_Emotes_And_Taunts_SourceFiles_v1.zip`, `ANIMATION_Goblin_Locomotion_SourceFiles_v2.zip`, `ANIMATION_Idles_SourceFiles_v3.zip`, `ANIMATION_Sword_Combat_SourceFiles_v5.zip` |
| INTERFACE (4) | `INTERFACE_Dark_Fantasy_HUD_SourceSprites_v3.zip`, `INTERFACE_Dark_Fantasy_Menus_SourceFiles_v1.zip`, `INTERFACE_Fantasy_Menus_SourceFiles_v2.zip`, `INTERFACE_Fantasy_Warrior_HUD_Source_Sprites_v3.zip` |
| POLYGON (6) | `POLYGON_Dark_Fantasy_Godot_4_6_2_v1_0_0.zip` + `POLYGON_Dark_Fantasy_SourceFiles_v3.zip`, `POLYGON_Dungeon_Godot_4_5_1_v1_0_1.zip` + `POLYGON_Dungeon_Pack_SourceFiles_v3.zip`, `POLYGON_Fantasy_Kingdom_Godot_4_5_1_v1_0_0.zip` + `POLYGON_Fantasy_Kingdom_SourceFiles_v5.zip` |

- Opgaven listede 13 produkter; ledgeren bekræfter dem alle, og de tre POLYGON-pakker findes i **to** arkiver hver (Godot-build + SourceFiles) = 16 arkiver. sha256 og bytes står i `data/art/synty_selection.json → packs` og i `docs/HOMECOMING.md` §2.
- **Licens:** SyntyPass Standard, 3 måneder, faktura SS-415943 (2026-08-16), 1 seat. Abonnementet udløber ca. **2026-11-16** — om under fire uger. EULA §12.3: efter udløb må spillet kun få små fejlrettelser; videre udvikling med assets kræver fornyelse. §12.4: intet nyt markedsføringsmateriale efter udløb. **Hent alt, også de valgfri pakker i §9, før udløb**, og beslut om fornyelse (`realmrend:docs/reviews/A07_synty_licence_summary.md`).
- **§1.4:** Synty-assets må ikke indgå i generativ AI (datasets eller "generation of 3D models utilising Generative AI"). Realmrends egen regel blev: aldrig Synty-indhold til Meshy eller AI-billedgenerering. Bemærk: Realmrend sendte alligevel Synty-screenshots til Grok-vision som kritik (`realmrend:docs/reviews/R16_grok_review.md`). Det er en gråzone mod deres egen politik (`realmrend:docs/access_report.md` A07). For LASTROOT gælder: send ikke captures med købt indhold til AI-billed- eller 3D-værktøjer. Del dem heller ikke offentligt (repoet er offentligt; `evidence/captures/` er gitignored).
- **PolyPerfect, Mixamo og Sidekick findes ingen steder i Realmrend** (grep over hele repoet). PolyPerfect er kun aktuelt for Tornhjort (B04).

## 2. Godot-build eller SourceFiles: hvad bruges hvornår

| | Godot-build (`*_Godot_4_x_x_*.zip`) | SourceFiles (`*_SourceFiles_vN.zip`) |
|---|---|---|
| Indhold | Et Godot-projekt: `Assets/<Pakke>/Prefabs/**.tscn`, `Models/extracted/*.res`/`*.mesh`, `Materials/*_mat.tres`, `Textures/*.png`, `Models/Collision/Synty_Character_Collider.tres` | Rå FBX + teksturer, fx `Source_Files/Characters/SK_Chr_King_01.fbx` |
| Godot-version | FK og Dungeon: 4.5.1 (= Lastroot). **Dark Fantasy: 4.6.2**, nyere end Lastroots 4.5.1 | uafhængig |
| Figurer | Én prefab rummer **alle** figurvarianter: Soldier-prefabben har 22 meshes, 21 skjulte; Dark Lord har 18, 17 skjulte (`realmrend:docs/reviews/A02_codex_access_test.md` fund 2). Skin-bindingen var **inert**: hverken knogleposer eller vendor-animation flyttede meshet (`realmrend:docs/reviews/R16_hero_summary.md`, `realmrend:tools/r16_pose_probe.gd`). Uløst. | Én figur pr. `SK_Chr_*.fbx`, rigget og skinnet. Blender/Godot-import virker (R05). |
| Statisk | Klar til brug: prefabs med materialer og colliders (R14 byggede hele Ravenhold af dem) | FBX + atlas; materialerne i FBX'en peger på teksturfiler, der ikke findes (`realmrend:tools/r06_retarget.py`: "Characters_0038:file373") |

**Beslutning for LASTROOT** (`data/art/synty_selection.json → _note`):
- `tools/synty/unpack.py` gemmer kun FBX/GLB/glTF/OBJ og billeder. Godot-buildets `.tscn/.tres/.res/.mesh` springes over. Godot-buildets versionskrav (4.6.2) betyder derfor intet for pipelinen. Uden apply_selection er det dog uvist, om buildet overhovedet indeholder rå FBX.
- **Figurer: SourceFiles først** (`SK_Chr_<Navn>.fbx`). Godot-buildets FBX er reserve.
- **Statiske modeller: Godot-buildet først**, fordi præcis de navne er set dér. SourceFiles er reserve. `apply_selection.py` prøver begge i den rækkefølge.
- **Atlas:** tag Godot-buildets `Textures/PolygonFantasyKingdom_Texture_01_A.png` (FK) og `Textures/Alts/PolygonDarkFantasy_01_A.png` (DF), også til SourceFiles-FBX. `synty_choices.json → atlas` gør det automatisk (stage.py lægger den først).
- Åbn aldrig Dark Fantasy-buildets scener i Lastroots 4.5.1-editor, og kopiér aldrig et Godot-builds `Assets/`-mappe ind i repoet. På Windows (ufølsom for store/små bogstaver) lander `Assets/` i Lastroots `assets/`, *uden for* de gitignorerede mapper. `doctor.py` advarer nu.

## 3. Mapper og filnavne set i de rigtige pakker

Navnene herunder er set i Realmrends scener, scripts og logs. De kaldes `verified_in_realmrend` i valget.

- **Rødder:** FK-buildet `Assets/PolygonFantasyKingdom/`, DF-buildet `Assets/Synty/PolygonDarkFantasy/` (bemærk den ekstra `Synty/`) (`realmrend:sandbox/fixture_manifest.json`). FK SourceFiles: `Source_Files/Characters/SK_Chr_King_01.fbx` (`realmrend:docs/reviews/R05_blender_roundtrip.log`).
- **Undermapper (FK):** `Prefabs/{Buildings/Preset_Houses,Castle,Characters,Characters/CharacterAttachments,Environments,Generic,Props,Props/Banners,Props/BattleGround,Props/Paths,Vehicles,Weapons}`, `Models/extracted`, `Models/Collision`, `Materials/{Alts,Flags,Misc}`, `Textures/{Alts,Castle,Misc}`. **DF:** `Prefabs/{Characters,Environment}` (ental!), `Models/Base`, `Textures/{Alts,Emissive,Misc}`.
- **Konventioner:** `SM_Chr_*` (figur-prefab/mesh i Godot-buildet), `SK_Chr_*` (rigget FBX i SourceFiles), `SM_Chr_Attach_*` (attachments), `SM_Env_*`, `SM_Prop_*`, `SM_Bld_*`, `SM_Wep_*`, `SM_Veh_*`, `SM_Generic_*`, `*_Optimized` (bygninger), `A_*` (animationsklip). Materialer: `PolygonFantasyKingdom_Mat_01_A_mat.tres`, `PolygonDarkFantasy_01_A_mat.tres`.
- **FK-figurer (22, alle set):** Bartender, Blacksmith_Female/Male, Fairy, FortuneTeller, Headsman, Hermit, Jester, King, Mage, Merchant, Monk, Nun, Peasant_Female/Male, Priest, Prince, Princess, Queen, Rider, Soldier_Female/Male (`SM_Chr_<X>_01`, `realmrend:game/characters/lord_raven.tscn`). Attachments: `SM_Chr_Attach_King_Cape_01`, `SM_Chr_Attach_King_Crown_01`, `SM_Chr_Attach_Soldier_01`.
- **FK miljø/props (udvalg):** `SM_Env_Tree_Large_01/02`, `SM_Env_Tree_Round_01–04`, `SM_Env_Tree_Thin_01–06`, `SM_Env_Tree_Pine_Cluster_01–05`, `SM_Env_Bush_Small_01–05`, `SM_Env_Bush_Cluster_01`, `SM_Env_Rock_Cliff_01–05`, `SM_Env_Rock_05`, `SM_Env_Ground_Flat_01`, `SM_Generic_Mountains_Grass_01/02`, `SM_Prop_Archway_01`, `SM_Prop_Street_Lamp_01`, `SM_Prop_Path_Rock_Group_01–03`, `SM_Prop_Spike_Fortification_01`, `SM_Wep_Shield_03/05/08`, `SM_Wep_Sword_01/09`, `SM_Prop_Bow_01`, `SM_Prop_Arrow_01` (`realmrend:docs/reviews/r14_asset_mapping.md`, `realmrend:game/maps/ravenhold_env.tscn`).
- **DF (set):** `SM_Chr_DarkLord_Male_01`, `SM_Env_Tree_Dead_01–04`, `SM_Env_Basalt_01/03/05`, `SM_Env_Cliff_Basalt_01–04`, `SM_Env_Grunge_01–03`, `SM_Prop_Barricade_01–03`, `SM_Prop_Bone_Pile_01/02`, `SM_Prop_Body_Skeleton_01`, `SM_Prop_Brazier_01`, `SM_Prop_Cage_Large_01`, `SM_Prop_Campfire_Setup_01`, `SM_Prop_Flag_Dark_01`, `SM_Prop_Flag_Witch_01`, `SM_Bld_Base_Pillar_01–03`. Butikslisten nævner desuden 14 figurer: Dark Lord, Demon ×2, Gargoyle, Grave Digger Male, Hunter Female/Male, Plague Doctor, Priest Female, Skeleton (+Flesh, Heavy Armor, Light Armor, Ranger) og Witch, samt vinger, masker og en krone som attachments. Filnavnene er ikke set → `pattern_only`.
- **Dungeon:** ingen fil åbnet i Realmrend. Butikslisten nævner Goblin_Female/Male/Shaman/Warchief/Warrior_Female/Warrior_Male (16 figurer i alt), 4 store krystaller og 12 svampe → `pattern_only`.
- **Store/små bogstaver:** Synty skriver `res://assets/…` (småt) mod mappen `Assets` i 2564 vendorfiler og stavefejlen `PolygonFantasyKingdon_Texture_Wall_Brick_01.png`. Det virker på Windows og fejler på Linux (`realmrend:sandbox/fixture_manifest.json`, A02 fund 4). Det er irrelevant for Lastroots FBX-vej, men match filnavne uden hensyn til store/små bogstaver (`apply_selection.py` gør det).

## 4. Skala og enheder (målt)

- `SK_Chr_King_01.fbx` (FK SourceFiles): **1,81 m** høj, 2,05 m armspænd i T-pose, 55 knogler, 1501 vertices → 6289 GPU-vertices efter glTF-sømdeling (normalt) (`realmrend:docs/reviews/R05_blender_roundtrip.log`).
- Godot-build-prefabs (meter): `SM_Chr_Soldier_Male_01` 2,05 × **1,94** × 0,42 m (med hjelm), 50 knogler, 3884 synlige tris. `SM_Chr_DarkLord_Male_01` 2,05 × **1,84** × 0,57 m, 50 knogler, 6948 tris. `SM_Bld_Bridge_01` 5,62 × 0,40 × 5,49 m, 602 tris (`realmrend:docs/reviews/R04_import_proof.log`).
- **Synty-FBX har et 0,01-skaleret armatur** (cm-arv fra Unity). Realmrend løste det i Blender med *Apply All Transforms* før eksport (`realmrend:tools/r05_blender_roundtrip.py`). Lastroots bygger måler skinnede meshes, som de tegnes, og retter cm→m (`docs/SYNTY_INTEGRATION.md` §6c fejl 2). Tjek alligevel `height_m` i `build_report.json`.
- Bækkenhøjde i idle er 0,85–0,87 m (R06). Det giver et godt tjek for, om skalaen er rigtig.
- Skala-hints pr. slot (native → mål) står i `synty_selection.json → scale_hint`. Eksempel: Askekronen = Dark Lord 1,84 m → 3,41 m (×1,85).
- Husenes `min_y` på −2,5 m blev fejlagtigt brugt som positiv højde (husene på stylter, R14). Brug bounds, ikke pivot (`realmrend:docs/reviews/R14_environment_polish_review.md`).

## 5. Materialer, atlas og farve

- Ét atlas pr. pakke: `PolygonFantasyKingdom_Texture_01_A.png` (+ `Alts/_01_B`, `_01_C`, `_02_C`, `_04_A`, normal maps i `Misc/`). DF: `PolygonDarkFantasy_01_A.png` + `Emissive/PolygonDarkFantasy_01_A_Emissive.png` + `Misc/PolygonDarkFantasy_01_Normals.png`.
- **FBX fra SourceFiles renderer hvidt**: materialet har en billedknude, der peger på en ikke-eksisterende fil. Realmrend bandt atlasset manuelt (`realmrend:tools/r06_retarget.py`, linjer om "bind the Synty atlas texture"). Lastroot bygger et fælles atlas-materiale pr. pakke (`slot_wrapper_builder.gd`) **men tog det alfabetisk første billede**, som i FK ville være `Alts/…_01_B.png` eller et normal map. Det er rettet nu: `apply_selection.py` skriver `"atlas"`, og `stage.py` lægger den rigtige først.
- Godot-buildets prefabs sætter materialet som `surface_material_override/0` på `MeshInstance3D`, ikke på meshet. Tjek `get_active_material()`, ikke `mesh.surface_get_material()` (A02 fund 5).
- **Multiply-tint kan kun mørkne og dæmpe, ikke ændre farvetone.** Rød kappe → blå krævede fladt materiale uden tekstur (`realmrend:docs/reviews/R16_hero_summary.md`, R15 §9). Til LASTROOTs askefjender: ét mørkt `ash`-materiale + emissive øjne/revner i stedet for at tone atlasset. Til bark/svamp: egne materialer eller et omfarvet atlas (egen, projektejet PNG er tilladt som afledt arbejde — rå vendorfil aldrig i git).
- Ruhed 0,75–1,0 for organisk, intet under 0,3 ("plastik"). Mål albedo-luminans 0,15–0,75 (`realmrend:docs/art/r15_art_kit_spec.md` §3).
- Grænse: atlasset giver "asset store-look", som kun et rigtigt tekstur/shader-pass fjerner (R15 Codex-review, "kendt loft").

## 6. UID-kollision og import

- FK- og DF-buildet leverer begge `Models/Collision/Synty_Character_Collider.tres` med **samme** `uid://cj5gwdnnnm3q3`. Det giver en duplicate-UID-advarsel og risiko for, at reference går til den forkerte pakke. Realmrend ændrede DF-kopien og dens 13 referencer til ny UID (`realmrend:tools/fix_vendor_uid_collision.ps1`, `realmrend:docs/reviews/R15_codex_independent_review.md`).
- **Portet:** `tools/synty/fix_vendor_uid_collision.py` (generel: finder alle dublet-UID'er i .tscn/.tres/.import/.uid, `--fix` omskriver kun referencerne `uid="OLD" path="res://<den fil>"`, idempotent, testet i `tools/synty/test_selection_tools.py`). **Kun relevant**, hvis du åbner flere Synty Godot-builds i ét Godot-projekt (fx et separat "vendor-browse"-projekt til at kigge prefabs igennem). Lastroots egen pipeline kopierer aldrig de filer.
- Indlejrede prefab-instanser plus ejede børn gav "incoming node's name clashes" ved load. Realmrend fladgjorde vendor-prefabs før pakning og fjernede `MeshCollider`-børn (`realmrend:docs/reviews/R15_codex_independent_review.md`). Lastroots wrapper ejer kun `Model` + `LRAnimations`; hold det sådan.
- **Bevisførelse (Codex R04-review, `realmrend:docs/reviews/A02_codex_access_test.md`):** "load + instantiate" er ikke en import-test. Kør `--import` på et rent cache, brug konsol-exe på Windows (`Godot_v4.5.1-stable_win64_console.exe`: pålidelig exitkode/stdout), mål *synlige* meshes og *world-space* bounds med nedre grænser, og tilføj noden til træet og vent ét frame før runtime-checks. Lastroots `build.sh`/RigLab følger allerede det mønster.
- Kameraer og lys i FBX'er sættes til "skip import" (Lastroot gør det, §6b). Sidebemærkning: Godot 4.7 krævede 3 frames for NavigationServer-sync (R12). Det er irrelevant for Lastroot, men gentagelsen er den samme: vent frames før målinger.

## 7. Humanoid-profil og retarget (det sværeste)

Kilder: `realmrend:docs/canonical_humanoid_profile.md`, `realmrend:docs/reviews/R06_animation_retarget.log`, `realmrend:docs/reviews/R08_summary.md`, `realmrend:tools/r06_retarget.py`, `realmrend:tools/r06_rig_compare.py`, `realmrend:assets_work/animations/retarget_report.json`.

**To Synty-rigs:**

| | ANIMATION-pakker + Godot-buildets figur-prefabs | FK SourceFiles-figur (`SK_Chr_King_01.fbx`) |
|---|---|---|
| Hofte / ryg | `Hips`, `Spine_01..03`, `Neck`, `Head` | `Pelvis`, `spine_01..03`, `neck_01`, `head` |
| Arm | `Clavicle_L`, `Shoulder_L` (= overarm), `Elbow_L` (= underarm), `Hand_L` | `clavicle_l`, `UpperArm_L`, `lowerarm_l`, `Hand_L` |
| Ben | `UpperLeg_L`, `LowerLeg_L`, `Ankle_L` (= fod), `Ball_L`, `Toes_L` | `Thigh_L`, `calf_l`, `Foot_L`, `ball_l`, `toes_l` |
| Ekstra | `Root`, `Prop_L/R` (våben), `Jaw`, `Eyes`, `Eyebrows`, fingre `Finger_0x`, `IndexFinger_0x`, `Thumb_0x` | `ik_*` (6 hjælpeknogler) |
| Hvile | arme **ned** | **T-pose**; knoglernes Y-akser er UE-orienterede, ikke anatomiske |

Kun `Hand_L/R` deles direkte. Realmrends Godot-build-skelet (Lord Raven) bruger animationspakkens navne (`Hips`, `Shoulder_L` …, 50 knogler + `Cape_*`), mens SourceFiles-FBX'en bruger UE-navnene.

**Hvad gik galt (R06→R08):**
1. Ren `COPY_ROTATION` foldede rygsøjlen: hovedet endte i bækkenhøjde, fordi hvile-akserne var ~90° forskellige.
2. Delta-from-rest frøs armene i T-pose (forskellige hvile-*poser*).
3. Y-akse-justering (v4) foldede ryggen igen, fordi UE-akserne ikke er anatomiske. Retninger skal tages fra barneknoglens position, aldrig fra knoglens Y.
4. Translationer låst til hvile gav hænder på forkerte steder. Kun rotationer må keyes (undtagen bækken-location).
5. **Numeriske tjek bestod alle de forkerte versioner.** Det var frame-review, der fandt fejlene. Oprethedsvagt: hoved ≥ 0,3 m over bækken undtagen i `death`.
6. Blender 5.2: `Action.fcurves` findes ikke (slotted actions). Brug `layers → strips → channelbags → fcurves`.

Realmrends løsning v5 var et Blender-bake (`r06_retarget.py`): delta-from-rest for kroppen, anatomisk armkorrektion, kun rotationer, eksport som én GLB med NLA-spor. Resultatet blev 8 klip på King-riggen, alle PASS, med bækken stabilt på 0,85 m.

**Konsekvens for LASTROOT:** Lastroot bruger *Godots* retarget i stedet for et Blender-bake: BoneMap på `SkeletonProfileHumanoid` + Rest Fixer *Fix Silhouette* (tærskel 5°) + `remove_immutable_tracks=false` (`tools/synty/humanoid_bone_mapper.gd`). Den løser netop punkt 1–4 (Godot omregner hvile-akser og -poser til profilen), og den er bevist på Synty-navngivne A-pose-rigs og Mixamo T-pose-rigs (§6c, 15/15). `HumanoidBoneMapper.parse` genkender begge Synty-navngivninger (`Pelvis`/`Hips`, `UpperArm_L`/`Shoulder_L`+`Clavicle_L`, `lowerarm_l`/`Elbow_L`, `Thigh_L`/`UpperLeg_L`, `calf_l`/`LowerLeg_L`, `Foot_L`/`Ankle_L`). Hvad der mangler: én rigtig Synty-figur + ét rigtigt Synty-klip i RigLab. Tjek punkt 5 med øjnene (arme ned i idle, hoved over bækken, slaget fremad). Virker Godot-vejen ikke på UE-riggen, er Realmrends Blender-bake reserveplanen (§10).

**Godot-build-skin inert (R16):** Lastroot instansierer aldrig Godot-buildets figur-prefabs, men det var en reel blokering i Realmrend. Brug den rå FBX gennem Godots egen import (det deformerer — bevist i §6c med Godots FBX-importer).

**Våben og attachments:** sværd på `Hand_R` via `BoneAttachment3D` (greb-offset −0,14/0,04/0 m, klinge vendt 180°), skjold på `Hand_L` med 0,10 m frigang. Kappen fulgte med som `SM_Chr_Attach_King_Cape_01` med egne `Cape_*`-knogler (`realmrend:docs/reviews/R16_hero_summary.md`, `realmrend:docs/reviews/r07_result.json`). For LASTROOT er svampehatte, stave, skjolde og kroner samme mønster.

## 8. Synty ANIMATION-pakker

- **Set i de rigtige pakker** (`realmrend:tools/r06_retarget.py`): `A_Idle_Standing_Masc.fbx`, `A_Walk_F_Masc.fbx`, `A_Run_F_Masc.fbx` (Base Locomotion); `A_Attack_HeavyCombo01A_Sword.fbx`, `A_Hit_F_React_Sword.fbx`, `A_Death_F_01_Sword.fbx` (Sword Combat); `A_POLY_BOW_Stand_Aiming_ToDrawn_Neut.fbx`, `A_POLY_BOW_Stand_Aiming_Drawn_Neut.fbx`, `A_POLY_BOW_Stand_Shoot_ToAiming_Neut.fbx` (Bow Combat). Mønster: `A_<Handling>_<Retning F/B/L/R>_<Variant>_<Stil: Masc/Femn/Neut/Sword>`.
- Én handling pr. FBX; klippene er på animationsriggen og har ingen skin.
- **Længder** (30 fps, frames fra `retarget_report.json`): idle 1,83 s · walk 1,10 · run 0,77 · sword_attack 2,10 · hit_react 0,90 · death 1,50 · bow_draw 0,70 · bow_aim 1,83 · bow_release 1,10.
- **Kontakt:** HeavyCombo01A har windup til 1,11 s, kontakt **1,19 s**, recovery 1,40 s og håndhastighed 10,4 m/s (`realmrend:assets_work/animations/timing/sword_attack.json`). Bueslip ved 0,067 s (`realmrend:sandbox/bow_release_timing.json`). LASTROOT bruger kontakt 0,30 s (attack), så **vælg et kort let slag** (`A_Attack_Light*_Sword`, `pattern_only`), eller sæt `animation_sets.json → sets.humanoid.contact.attack = 1.19`, hvis det verificerede HeavyCombo bruges. Lange klip forsinker `finished`.
- **Root motion:** Sword Combat har både root-motion- og in-place-versioner (butikken: 105 FBX). Bibel-reglen i Realmrend var in-place for squads. Lastroots bygger fjerner hoftens fremdrift. Tjek, at en evt. `Root`-knogle heller ikke flytter figuren.
- **Goblin Locomotion** har sin egen goblin-rig. Realmrend krævede en separat retarget-test før brug, og den blev aldrig kørt. I valget er den kun en variant for små figurer.
- Ingen af de ejede pakker har **magi/cast** eller **"rejse sig"**. `cast` får en emote eller bueslip (valgfri), ellers procedural. Mixamo "Standing 1H Magic Attack 01" er gratis reserve.
- Fingre mappes ikke i v1 (tvetydige sidenavne `Finger_01_1` i animationsriggen; `retarget_report.json → unmapped_anim_bones`). Ved LASTROOTs kameraafstand er det uden betydning.

## 9. Pakker der mangler for LASTROOT

Ejede pakker dækker humanoider, sten/basalt, døde træer, props, svampe og krystaller (Dungeon). Der mangler **firbenet dyr** (B04), en **treant** (B06) og en **golem** (bedre B01). En flydende rodplade og et stammesegment har ingen pakke — de forbliver procedurale (se valget). Med aktivt SyntyPass kan katalogpakker hentes uden ekstra pris (hent før udløb):
- **POLYGON Fantasy Rivals** — Forest Guardian, Fort/Elemental Golem, Troll, Barbarian Giant, Dwarf (Unity-butikslisten, `pattern_only`).
- **POLYGON Nature / Enchanted Forest – Nature Biome** — kun valgfri opgradering af træ og rødder. Indhold (svampe, rødder) er ikke bekræftet.
- **PolyPerfect Low Poly Animated Animals** (køb, ikke SyntyPass) — kun B04.

## 10. Blender (og "Blender MCP")

- **Realmrend brugte ikke Blender MCP**: ingen MCP-konfiguration, nævnelse eller log i repoet. Blender 5.2.0 LTS kørte scriptet i baggrundstilstand: `blender --background --python tools/r05_blender_roundtrip.py` (`realmrend:docs/toolchain.md`, `realmrend:tools/r05_blender_roundtrip.py`, `r06_rig_compare.py`, `r06_retarget.py`). MCP står kun som rolle i biblerne ("Blender / scripts / MCP: rignormalisering, sockets, eksport, simple meshrettelser" — `docs/BIBLE.md` og `genesisark:docs/BIBLE.md`).
- **Roundtrip (R05):** FBX-import → *Apply All Transforms* (retter 0,01-armaturet) → GLB → re-import → sammenlign knogler (55 = 55) og mål (±2 %). Vertex-tal vokser ved glTF-sømdeling og er ikke en fejl. Ignorér Blenders glTF-importørs pladsholder-icosphere.
- **Rig-sammenligning (R06 trin A):** importér figur + ét klip, sammenlign knoglesæt (`r06_rig_compare.py`). Billigt, og det fandt de to navngivninger.
- **Hvornår i LASTROOT:** (a) hvis Godots retarget fejler på FK-figurens UE-rig: kør Realmrends `r06_retarget.py`-metode (bake Synty-klip på figuren → GLB med NLA-spor) og vælg GLB'en som `manual`. (b) Til attachments, der skal sidde fast i meshet (svampehat som egen mesh, barkplader). (c) Til `make_humanoid_pack.py`-testfigurer (`docs/SYNTY_INTEGRATION.md` §6c, `pip install bpy==5.2.2`). MCP (live Blender styret af en agent) er nyttigt til (b) interaktivt. Gem altid originalen urørt, aflever bearbejdet fil + GLB + importtest (biblens krav), og send aldrig Synty-meshes til AI-generering (§1.4).
- **Faldgruber:** Blender 5.2 slotted actions (§7 punkt 6); `transform_apply` på alt før eksport; NLA-spor muted, så glTF-eksporten ser ét klip pr. spor; nulstil `matrix_basis` mellem klip; FBX-teksturknuder med døde stier dropper glTF-eksporten lydløst (hvid model).

## 11. Ydelse (målt i Realmrend)

- Udviklingsmaskine: Ryzen 9 9950X3D, RTX 5090, 47 GB, Windows 11. Der var **ingen mellemklasse-benchmark** (A12 udskudt), så Realmrends performance-kategori var aldrig godkendt (`realmrend:docs/access_report.md`).
- Figurer: 3884–6948 synlige tris og 50 knogler pr. figur; prefabs bærer skjulte varianter (hukommelse, ikke tris). Lastroots 18 figurer på skærmen ≈ 70–125 k tris — fint for desktop. Til web/telefon: hold øje med skinnede meshes (`evidence/perf/`).
- Draw calls: Realmrend samlede 193 unikke materialer/meshes til 17 materialer + 3 meshes (R12). Synty-atlas = ét materiale pr. pakke, hvilket passer med Lastroots `ProxyMerge`-tal (midtkamp 388 draw calls).
- Brug `*_Optimized`- og cluster-varianter til store bygninger og skove (R14 forbehold 4).

## 12. Review-fund der gælder LASTROOT

| Fund | Kilde | Hvad LASTROOT gør |
|---|---|---|
| "PASS" var bredere end beviset; load ≠ import, skjulte varianter maskerer fejl | `realmrend:docs/reviews/A02_codex_access_test.md` | RigLab + `build_report.json` måler synlige bounds/højde; skriv aldrig PASS for en købt figur uden RigLab-kig |
| Numeriske animationstjek bestod forkerte retargets | `realmrend:docs/reviews/R08_summary.md` | Godkend først efter frame-review (arme ned, hoved over bækken, slag fremad) |
| Grok-kritik var nyttig som detektor, men faktuelt forkert i flere runder ("sværdet flyder") | R08, R15, R16 Grok-reviews | AI-kritik er forslag; ejeren godkender visuelt; zoom før handling |
| Prefabs svævede/stod på stylter (pivot ≠ bund) | `realmrend:docs/reviews/R14_environment_polish_review.md` | Bygger lægger bounds på y=0; tjek fødder på gitteret |
| Store collider-klodser og cluster-AABB'er løftede skove | R14 | Ingen vendor-colliders i wrappers; klikmål forbliver proxyens |
| Nested prefabs + ejede børn → name clashes | R15 Codex | Wrapper = `Model` + `LRAnimations`, intet andet |
| Duplicate UID mellem pakker | R15 Codex | `tools/synty/fix_vendor_uid_collision.py` |
| Dokument-drift (toolchain sagde "mangler" efter fix) | A02 fund | Status kun fra beviser (`write_evidence.py`) |
| Tre fejl på samme årsag → ny metode | `realmrend:docs/bible_v1.0_extracted.txt` §"No infinite perfection loop" | = Lastroots AGENTS-regel om højst tre hypoteser |

## 13. Det der stadig er usikkert

- Om Godot-buildene indeholder rå FBX (eller kun `.tscn`/`.res`). `apply_selection.py` falder tilbage til SourceFiles, hvis ikke.
- Den præcise mappe i SourceFiles for DF/Dungeon og ANIMATION-pakkerne. Mønstrene matcher på filnavn i alle mapper.
- Figurfilnavne i DF og Dungeon (fra butikslister) og Dungeon-teksturens navn. Kør `--dry-run` efter unpack og se tvetydigheder.
- Godot 4.5.1's retarget af FK-figurens UE-rig (Pelvis/UE-akser) er ikke prøvet. Realmrend brugte Blender-bake på 4.7.1.
- Root-motion-placering (`Root` vs `Hips`) i Synty-klip.
