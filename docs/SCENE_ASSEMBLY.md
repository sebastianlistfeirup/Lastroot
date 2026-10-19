# Samleguide: visuelle slots i BattleScene

Kampscenen bygges af koordinatoren; denne guide beskriver **kontrakten** for det visuelle lag (`scripts/runtime/visual/`), så proxies i dag og købte modeller senere kan skiftes uden kodeændringer. Domænet indeholder ingen NodePath eller Transform3D (biblen); alt herunder er præsentation.

## Hurtig vej

```gdscript
var v := VisualSlots.make("unit.B01")        # Node3D, aldrig null (ukendt id -> magenta boks + warning)
anchor.add_child(v)                          # fødder = origin, front = -Z
v.rotation_degrees.y = -90.0                 # allierede ser mod +X (fjenderne); fjender: +90
var anim := v.get_node("UnitAnimator") as UnitAnimator
anim.play(&"attack", speed)                  # idle summon attack cast hit death defend victory move
await anim.finished                          # kommer ALTID (clip, procedural eller timeout)
var badge_y := VisualSlots.head_height("unit.B01")   # hp/attack-badge (2D-overlay) over hovedet
```

## API

| Kald | Betydning |
|---|---|
| `VisualSlots.make(slot_id) -> Node3D` | Wrapper (købt model), hvis `asset_slots.json` → `scene` eller `slot_scenes.json` peger på en eksisterende scene; ellers procedural proxy. Root-meta: `slot_id`, `is_proxy`, `kind`, `height_m`. Væsner, fjender og `stage.heart` har barnet `UnitAnimator`. Ingen fysik/kollision. |
| `VisualSlots.has_real_asset(id)`, `slot_ids()`, `ids_of_kind(kind)`, `slot(id)`, `head_height(id)`, `bounds(node)`, `reload()` | Opslag. `head_height` = målt top + ~0,2 m (wrapper: byggerens målte højde × `scale` + 0,25). |
| `UnitAnimator.play(state, speed=1.0)` | Spiller clip `lr/<state>` (eller mappet clipnavn) in place; ellers procedural tween på `Model`-barnet. Rooten røres aldrig (du ejer dens position mellem anchors). |
| `signal finished(state)` | Én gang pr. `play()`; også hvis en ny `play()` afbryder, og senest `varighed/speed + 0,6 s` (sikkerhedsnet). Loop-tilstande (`idle`, `move`) sender `finished` efter første cyklus og fortsætter. Efter `summon/attack/cast/hit/victory` går figuren selv tilbage til `idle`. `death`: proxyen synker, falmer og skjules; en rig holder dødsclippets sidste frame (fjern noden efter `finished`). |
| `signal contact(state)`, `contact_time(state)` | Kontaktframe for attack/cast (standard 0,30 / 0,38 s ved speed 1; del med speed). Kun til feedback-synk (hit-fx, tal-pop) — skade er allerede afgjort. |
| `has_clip(state)` | Rig: true hvis der findes et rigtigt clip. Proxy: true for alle tilstande (proceduralt er dens clip). Manglende clip spiller stadig procedural + `finished`. |
| `snap(state)` | Skip/load: sæt slutpose med det samme (`death` = skjult, ellers idle). |
| `UnitAnimator.reduced_motion` (static) | Mindre udsving, ingen knockback-rotation; sæt fra settings. |
| `FxBuilder.launch(parent, from, to, duration, "fx.spore_bolt", "fx.heal")` | Flyver en sporekugle i bue fra stav til mål og spiller impact-fx. |

## Koordinater (meter)

| Element | Placering |
|---|---|
| Etager | `stage.floor_roots/trunk/crown` på y = 0 / 4,5 / 9,0. Overflade y=0 lokalt; spilbart x −5,5…+5,5; dybde 3,2 (z −1,6…+1,6). Forkanten (+Z, mod kameraet) er fri; props kun på bagkanten (z ≈ −1,45). Undersiden af Stammen/Kronen holdes bag figurerne på etagen nedenunder (z < −1,2) eller over y −0,75 lokalt, så 3,4 m bossen kan stå under. |
| Stamme | `stage.trunk` er ét segment fra y=0 til 4,5, centreret x=0, z ≈ −3,2 (forside z ≈ −1,4 i enhedshøjde). TreeStage instancerer ét **pr. etage ved etagens y** (0 / 4,5 / 9); segmenterne fliser lodret. Barnet `StageVariant` vælger udseende efter verdenshøjden: Rødder (mørk, violette svampe), Stamme (små ravvinduer højt oppe, tynde turkise årer), Krone (stammen smalner og deler sig i grene, der omkranser hjertet, med lysegrøn løvkrone og blomster til siderne). Intet lyst objekt ved x≈0 i enhedshøjde. |
| Hjerte | `stage.heart` (~2 m inkl. vugge, egen turkis OmniLight3D) på `(0, 12.4, −0.4)` (StageLayout.heart_pos); `fx.heart_pulse` samme sted. Har `UnitAnimator`: `idle` er en langsom puls af krystal + halo (reduced motion: næsten stille), `hit` blinker rødt. TreeStage.pulse_heart skalerer roden — det spiller sammen. |
| Baggrund | `stage.backdrop` ved origin; alt ligger z < −15. |
| Figurer | Stå omkring z = 0 (maks. dybde ±1,0). Allierede venstre (x < 0) med `rotation_y = -90` (front mod +X), fjender højre med `+90`. Lidt mod kameraet (−115 / +115) giver 3/4-visning som i style gate. Fodaftryk langs X ≈ figurens Z-dybde: 1-plads ≤ ~0,9 m, 2-plads ≤ ~2,1 m, 3-plads ≤ ~2,6 m. |
| Mutationer | Instancér i rammen for det, de pynter (som `TreeStage.apply_mutations`): `M01` ved `(0, 0, 0)` — bredere barkkant under Rødder-pladen (under overfladen) + tykke rødder over bagkanten og ned ad yderhjørnerne med ravspidser; `M02` ved `(0, 4.5, 0)` — tyk glødende ring højt på stammen (lokal y ≈ 3,35, over hovederne) + turkise årer; `M03` ved `(0, 9, 0)` — blomstertræer i bagerste hjørner, guldblomster på bagkanten, få drivende kronblade (14 CPU-partikler); `M04` ved hjertets position — dobbelt halo, turkis ring, 12 skår, ét ekstra lys. Ingen del går ind i spilområdet (testet) og klikflader ændres aldrig. |
| FX | Origin = den ramte figurs fødder (dimensioneret til ~1,6 m figur; skalér med `head_height/1,8`). One-shot (`meta one_shot`, `lifetime_s`) frigør sig selv; status-loops (poison, armor, thorns, growth, heart_pulse) fjerner du selv. CPUParticles3D (virker i Compatibility/web). |

## Liv i tomgang

Etager, props og mutationer har barnet `GlowPulse`: små `Glow_*`-dele (svampeprikker, krystaller, lanterner, årer, blomster) ånder langsomt med hver sin fase (få tweens, ingen ekstra lys). Med reduced motion står de stille. `UnitAnimator.motion_reduced()` læser både `UnitAnimator.reduced_motion` og autoloaden `SettingsService.reduced_motion`, så der kræves ingen integrationskode.

## Kunstgate for TreeStage

`scenes/tests/stage_mutations.tscn` bygger den rigtige TreeStage, kalder `apply_mutations([...])`, rammer kameraet med `frame_camera(false, 0.23)` og stiller repræsentative figurer på de rigtige anchors. `tools/synty/capture_battle.sh` tager den og de rigtige kampskærme (`--setup=boss`, `--setup=midbattle`, portræt 390×844) til `evidence/asset_pipeline/`.

## Kamera og lys (forslag, matcher style gate)

Ortografisk, let skråt sidekamera (fx `size ≈ 17`, pitch −10…−12°) viser alle tre etager + hjertet. Miljø: baggrund `#1b1530`, ambient `#7b6aa8` × 0,55, varm sol `#ffe2b8` × 1,25 fra (−42°, −35°) med skygger, kølig rim `#6a7cff` × 0,45. Emissive dele er unshaded og læses uden glow. **Bemærk:** glow i Compatibility-rendereren gjorde hele billedet violet i vores test (xvfb/llvmpipe) — prøv den på rigtig hardware før den slås til.

## Tests og værktøjer

* `tests/unit/test_visual_slots.gd` — `class_name TestVisualSlots extends RefCounted`; hver `test_*()` returnerer `Array` af fejltekster (tom = bestået). Kør selvstændigt: `godot --headless --path . --script res://tools/synty/run_visual_tests.gd`.
* `tools/synty/check_scripts.sh` — parse-tjek af alle scripts i det visuelle lag.
* `tools/synty/measure_slots.gd` — målte bounds for alle slots → `evidence/asset_pipeline/slot_bounds.json`.
* `tools/synty/selftest.sh` — importkæden ende-til-ende med falske pakker → `evidence/asset_pipeline/selftest.json`.
* `tools/synty/capture.sh` — skærmbilleder af style gate og RigLab.
* `tools/synty/gen_slots.py` — genskaber `asset_slots.json`, `vendor_suggestions.json`, `animation_sets.json`, ledgers og `ASSET_PLAN.md` fra én kilde.
