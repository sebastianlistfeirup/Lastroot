# Synty · PolyPerfect · Mixamo → LASTROOT

*Godot 4.5.1 · gælder biblens afsnit "Synty og PolyPerfect: konkret assetplan" og "Animation: dramatisér et allerede afgjort resultat".*

Guiden er skrevet til dig som ejer. Du behøver ikke kunne programmere. Spillet kører i dag med procedurale low-poly proxies for hvert visuelt *slot*. Du skifter ét slot ad gangen til en købt model; kampreglerne ændres aldrig af grafik.

> **Ærlighedsnote:** Ingen købt pakke er åbnet i dette repository. Alt om **filnavne, mapper, skala og indhold** i Synty-, PolyPerfect- og Mixamo-filer er typiske konventioner, ikke kontrolleret mod dine filer — derfor står der **unverified — check actual pack contents** i `data/art/vendor_suggestions.json`. Værktøjskæden er derimod afprøvet ende-til-ende med falske pakker (`tools/synty/selftest.sh`, resultat i `evidence/asset_pipeline/selftest.json`).

---

## Hurtig vej

```bash
# 1. Pak ud i karantæne (kommer aldrig i git — repoet er offentligt)
python3 tools/synty/unpack.py "D:/Synty/POLYGON_Nature.unitypackage"
python3 tools/synty/unpack.py "D:/Synty/POLYGON_Dark_Fantasy_SourceFiles.zip"
python3 tools/synty/unpack.py "D:/PolyPerfect/Low_Poly_Animated_Animals.unitypackage"
python3 tools/synty/unpack.py "D:/Mixamo/LASTROOT_clips"            # en mappe med FBX fra mixamo.com
# 2. Foreslå model pr. slot + Mixamo-clip pr. tilstand -> data/art/synty_choices.json
python3 tools/synty/match.py
# 3. Kig listen igennem: ret "source", sæt "status": "approved" (lås) eller "skip" (behold proxy).
#    "weak" bygges først, når du har godkendt den. "rotation_y": 0/180 vender en figur.
# 4. Byg alt i én kommando: kopierer KUN de valgte filer ind, importerer, sætter knoglekort
#    og pakkens atlas i importindstillingerne, bygger wrappers og mapper slottene.
tools/synty/build.sh
# 5. Se resultatet: scenes/tests/rig_lab.tscn (én figur) og scenes/tests/asset_gallery.tscn
#    (style gate: alle figurer under samme lys). Rapport: evidence/asset_pipeline/build_report.json
# 6. Se ALT side om side med dagens proxyer: én kommando kører alle capture-scener efter
#    hinanden (kamp, hjerte, dioramaer, galleri, RigLab + tilstandsark, branding,
#    metaskærme, kortgalleri, kampens interaktionstilstande) og laver en kontaktark-side
#    og en før/efter-side mod baseline (procedurale proxyer, i git).
tools/capture_all.sh synty --compare=proxies_baseline
#    -> evidence/captures/<dato>_synty/index.html og compare_proxies_baseline.html
```

**Trin 6 i detaljer** (`tools/capture_all.sh [label] [--compare=<label>] [--no-date] [--only=gruppe,gruppe]`):

- Resultatet havner i `evidence/captures/<YYYY-MM-DD>_<label>/<gruppe>/`. Standard-label er `current`; med `--no-date` falder datoen væk. Alle billeder er skaleret ned til højst 1280 px bredde (JPEG q84, PNG når der er gennemsigtighed). `manifest.json` lister hvert billede med dets originale størrelse, og `capture.log` gemmer Godots output.
- `index.html` viser alle billeder grupperet efter område med relative stier, så mappen kan zippes og sendes videre.
- `--compare=proxies_baseline` skriver `compare_proxies_baseline.html`: før (baseline) og efter (denne kørsel) side om side, parret efter gruppe og filnavn. Et billede, der kun findes på den ene side, vises som "not captured". `--compare` virker med ethvert label: først leder den efter en mappe med præcis det navn, ellers den nyeste `*_<label>`.
- Grupper: `battle heart dioramas gallery riglab branding meta cards battle_ui`. `--only=battle,gallery` er nyttigt, når man justerer én ting.
- Scenerne køres altid **én ad gangen**, aldrig parallelt, fordi metaskærmene tager backup af gemt spil i `user://`. Kør heller ikke `tools/check.sh` samtidig.
- `meta_capture`, `card_gallery` og `battle_capture` skriver til deres faste evidence-mapper. Scriptet kopierer det, kørslen lavede, og sætter de committede filer tilbage bagefter, så arbejdskopien forbliver ren. Branding renderes til arbejdsmappen og rører ikke `assets/branding/`.
- Baseline `evidence/captures/proxies_baseline/` blev lavet med `tools/capture_all.sh proxies_baseline --no-date`, før der var importeret noget købt. Den forbliver i git som sammenligningsgrundlag. Nye kørsler med rigtige assets bør **ikke** committes: de viser købt indhold, og repoet er offentligt.
- Det kræver godot 4.5 (`GODOT_BIN`), `xvfb-run`, python3 og Pillow. `evidence/captures/` har `.gdignore`, så Godot ikke importerer billederne.

Afprøv kæden uden købte filer: `tools/synty/selftest.sh` (falske Synty-, PolyPerfect- og Mixamo-pakker → hele kæden → kontrol i en kørende scene → oprydning).

---

## 1. Hvad der sker, trin for trin

| Trin | Værktøj | Resultat | I git? |
|---|---|---|---|
| Udpak | `unpack.py` | `assets/quarantine/<pakke>/` + `manifest.json` (sti, størrelse, sha256). Unity-filer (.prefab, .mat, .meta, .cs, .controller, shaders) springes over. Mappen har `.gdignore`, så Godot ikke importerer tusindvis af filer. | **Nej** (gitignored) |
| Match | `match.py` | `data/art/synty_choices.json`: slot → valgt fil + alternativer; `animations.humanoid`: tilstand → clipfil | Ja (kun navne) |
| Stage | `stage.py` | Kun valgte filer + pakkens atlas-teksturer til `assets/imported/<pakke>/` | **Nej** (gitignored) |
| Import | Godot | `.import` + cache | — |
| Byg | `build_wrappers.gd` | `art/prefabs/<slot>.tscn`, `art/animations/*.res`, `art/rigs/*.bonemap.tres`, `art/materials/<pakke>_atlas.tres`, `data/art/slot_scenes.json` | Ja (små filer uden købt indhold) — men de virker kun på en maskine, hvor pakkerne er stagede. Uden dem falder spillet roligt tilbage til proxyen. |

**Licens:** købte filer kommer aldrig i git. Det, der committes, er filnavne/valg (`synty_choices.json`), wrappers, knoglekort og materialer, der *peger på* de gitignorede filer. Før du committer: `git status` må ikke vise noget under `assets/quarantine/` eller `assets/imported/` (bortset fra README).

## 2. Hvordan wrapperen normaliseres

Wrapperen `art/prefabs/<slot>.tscn` indeholder `Model` (den importerede fil, urørt) og evt. `LRAnimations` (AnimationPlayer med biblioteket `lr`, clips navngivet efter tilstandene). Spillet tilføjer selv `UnitAnimator`.

| Slot-type | Tilpasning (`fit`) |
|---|---|
| Væsner og fjender (`unit.*`, `enemy.*`) | `height`: skaleres ensartet til slottets højde (størrelsessproget: små 0,9–1,4 m, 3-pladsers ~2,4 m, boss ~3,4 m). Fødder på y=0, centreret, front mod **-Z** (`rotation_y` 180 er standard for figurer, da de typisk importeres med front mod +Z — tjek i RigLab). |
| Etager (`stage.floor_*`) | `footprint`: bredden skaleres til 11,6 m (spilbart område x −5,5…+5,5), **overfladen** lægges på y=0. |
| Stamme, hjerte | `height` (stammesegment 4,5 m; hjerte ~2 m), centreret på proxyens midte (stammen står bag spilleområdet, z ≈ −3,2). |
| Props, baggrund, mutationer | `natural`: ægte størrelse; kun cm→m (×0,01) rettes automatisk. Advarsel, hvis højden er under 40 % eller over 250 % af proxyen. |

Alt kan overstyres pr. slot i `synty_choices.json`: `"fit"`, `"extra_scale"`, `"align"` (`"base"`/`"top"`), `"rotation_y"`. Fintuning uden at bygge om: `"scale"`, `"offset"`, `"rotation_y"` i `data/art/asset_slots.json` (bevares når `gen_slots.py` køres igen). En hånd-sat `"scene"` dér vinder altid over byggerens mapping.

**Materialer:** Synty-FBX mister ofte koblingen til atlas-teksturen. Byggeren laver ét fælles materiale pr. pakke (`art/materials/<pakke>_atlas.tres`) og sætter det i modellens importindstillinger ("Use External") — præcis det, du ellers gør i Advanced Import Settings. Emissive dele (rav, turkis, ember) farvelægges efter `data/art/palette.json`, hvis du vil matche proxyens lys.

## 3. Figurer og animation

**Tre rigfamilier** (`rig_family` i `asset_slots.json`):

* **humanoid** — alle tobenede væsner, fjender og bossen. Byggeren genkender Synty-knoglenavne (`Hips, Spine_01, Clavicle_L, Shoulder_L, Elbow_L…`) og Mixamo-navne (`mixamorig:Hips, LeftArm, LeftUpLeg…`) og sætter Godots humanoide bone map i importindstillingerne. Derfor kan **ét Mixamo-clipsæt spille på alle humanoide figurer** (biblioteket `art/animations/humanoid.res`). Rapporten viser kerneknogler, der evt. mangler.
* **quadruped** — Tornhjort (B04). Brug et PolyPerfect-dyr med **egne** clips (hjort/kronhjort; navne som `Idle`, `Attack`, `Death`, `Walk` — skal verificeres). Byggeren matcher dyrets indbyggede clips til tilstande via nøgleord og laver `art/animations/unit.B04.res`. **Aldrig** humanoid retarget på fire ben (biblen). Tornegevir laves som attachments af POLYGON Nature-grene.
* **static** — Svampevæg (S03): ingen knogler; `UnitAnimator` bruger procedural bevægelse.

**Mixamo-download:** Format *FBX Binary*, 30 fps, **In Place** slået til (gang), *Without Skin* for clip-filer. Navngiv filerne med Mixamo-navnet (fx `Breathing Idle.fbx`, `Punching.fbx`, `Standing 1H Magic Attack 01.fbx`, `Hit Reaction.fbx`, `Dying.fbx`, `Standing Block Idle.fbx`, `Victory.fbx`, `Standing Up.fbx`, `Walking.fbx`) og læg dem i én mappe. `match.py` læser tilstanden ud af filnavnet (nøgleord i `data/art/animation_sets.json`). Byggeren fjerner desuden hoftens vandrette fremdrift (in-place), så root motion aldrig flytter formationen.

**Tilstande** (biblens minimumsbibliotek): `idle, summon, attack/cast, hit, death, defend, victory` + `move` (opstigning mellem etager). En manglende clip er ingen fejl: `UnitAnimator` spiller en procedural version og sender **altid** `finished`, så runnet aldrig hænger. RigLab og `docs/ANIMATION_LEDGER.csv` viser, hvad der mangler.

**Kontaktframe:** `UnitAnimator.contact_time(state)` (standard 0,30 s for attack, 0,38 s for cast; ret pr. rig i `animation_sets.json` → `contact`). Den synkroniserer kun feedback; skade er allerede afgjort af reglerne.

## 4. Kontrol: RigLab og style gate

* **RigLab** (`scenes/tests/rig_lab.tscn`, F6): én figur mod 1 m-gitter, 1 m-kube, højdestang og en "front = −Z"-pil. Spiller alle slottets tilstande i ring og viser for hver: clip / procedural / **MISSING**, kontakttid og hvor hurtigt `finished` kom. Rapporterer højde, fødder (y), facing og problemer i klar tekst. ←/→ skifter figur, Space næste tilstand, R reduced motion.
* **Style gate** (`scenes/tests/asset_gallery.tscn`): 1 line-up af alle 18 figurer på tre hylder, 2 scenen (tre etager, stamme, hjerte, baggrund), 3 props/fx, 4 biblens gate (begge champions, to normale, to fjender). A afspiller en tilstand på alle.
* Skærmbilleder: `tools/synty/capture.sh` → `evidence/asset_pipeline/*.png` (kræver xvfb-run).

Godkend en figur, når: højden passer til størrelsessproget, fødderne står på gitteret, den vender mod pilen, attack/hit/death ser stabile ud, og materialet matcher nabofigurerne under samme lys. Skriv derefter i `docs/ASSET_LEDGER.csv` (`review_status` fx `APPROVED`) — rækker, der ikke står som `PROXY`/`NEEDED`, bevares når ledger genskabes.

## 5. Editor-dock "Asset-slots"

Slå til under *Project → Project Settings → Plugins → "LASTROOT · Asset-slots"*, eller tilføj i `project.godot`:

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/lastroot_slots/plugin.cfg")
```

Docken viser alle slots (● model / ○ proxy), pakke- og søgeforslag, matcherens valg og alternativer. Markér en model i FileSystem og tryk **Brug valgt fil**, eller **Brug valg**. "Drej model" retter facing. **Åbn wrapper**, **Fjern**, **RigLab** og **Style gate** er genveje. Docken bruger samme bygger som `build.sh`.

## 6. Fejlfinding

| Symptom | Løsning |
|---|---|
| Figuren vender ryggen til fjenden | `"rotation_y": 0` (eller 180) i `synty_choices.json`, byg igen. RigLab viser `facing`. |
| 100 gange for stor/lille | cm/m-fejl: byggeren retter normalt selv; ellers `"extra_scale"`. |
| Lyserød/hvid model | Atlas mangler: tjek at pakkens `*_Texture_*.png` blev staget (`assets/imported/<pakke>/staged.json`), kør `build.sh` igen. |
| "bone map missing: …" | Knoglenavnene kendes ikke; åbn modellens Advanced Import Settings → Retarget → BoneMap og ret de røde felter, gem, byg igen. |
| Clip spiller ikke | RigLab viser MISSING → tilføj clipfil og kør `match.py` + `build.sh`, eller angiv clipnavnet i `animation_sets.json` → `sets.<rig>.clips`. |
| "import settings updated" | Normalt; `build.sh` importerer og bygger op til tre gange af sig selv. |
| Wrapper findes, men proxy vises | Pakken er ikke staget på denne maskine (fx efter `git clone`): kør `tools/synty/build.sh`. |

## 6b. Første rigtige import (lært af en ægte FBX)

Kæden er kørt mod to rigtige FBX-filer (assimp's BSD-licenserede testmodeller, slettet igen efter kørslen) i Godot 4.5.1. Resultatet står i `evidence/asset_pipeline/fbx_dryrun.json`. Det her er, hvad der faktisk skete, og hvad du skal gøre:

1. **Start med at se, hvad filen indeholder:**
   `godot --headless --path . --script res://tools/synty/model_probe.gd -- res://assets/imported/<pakke>/<fil>.fbx`
   Den viser knogler, om de kan mappes til humanoid, clips (navn, længde), mål (cm eller m?) og op-akse.
2. **FBX går gennem Godots indbyggede FBX-import (ufbx).** Det virker uden Blender. Filer, der henviser til eksterne `.jpg`/`.png` via sti, giver advarsler og bliver hvide, hvis billederne ikke ligger ved siden af. Kopiér de nævnte teksturer ind ved siden af FBX'en (stage.py tager kun `*Texture*` og `Textures/`-mapper med).
3. **FBX-scener har ofte deres eget kamera og lys** (testfilerne havde `Camera` og `Lamp`). Byggeren sætter dem nu til "skip import" i `.import`-filen, og `VisualSlots.make` fjerner resten ved kørsel. Du skal ikke gøre noget, men vid at et ekstra import-pas er normalt.
4. **Knoglenavne afgør retarget.** Synty-/Mixamo-navne mappes automatisk. Generiske navne (`Bone`, `Bone.001` …) kan ikke. Byggeren nægter nu at skrive et tomt bone map (over 4 manglende kerneknogler) og falder tilbage til modellens egne clips. RigLab skriver tydeligt: "slot expects a humanoid but the rig has no humanoid bone map". Løsning: vælg en anden model, omdøb knoglerne i Blender, eller brug modellens egne clips.
5. **Egne clips med generiske navne** (fx `Armature|Action`) matcher ingen tilstand. Skriv dem selv i valget: `"clips": {"idle": "Armature|Action", "attack": "…"}` i `synty_choices.json`. Rapporten lister de indlejrede clipnavne.
6. **Cm og flade modeller:** et objekt i centimeter, der skaleres efter højde, kan blive kæmpestort i fodaftryk, hvis det ligger ned eller er eksporteret Z-op. Byggeren advarer nu ("footprint … too wide"). Løsning: `"rotation_y"`/en anden model, `"fit": "natural"` eller `"extra_scale"`.
7. **Facing** kan ikke gættes ud fra generiske knogler (`facing unknown`). Se på "front = −Z"-pilen i RigLab og sæt `"rotation_y"`.

Ikke verificeret endnu: retarget af en rigtig humanoid FBX (Synty/Mixamo). Den del er kun bevist med glTF-selvtesten. Første gang du importerer en købt figur, så kør `model_probe.gd` på den og kig i RigLab, før du godkender den.

## 7. Filer

* `data/art/asset_slots.json` — slotregister (genereres af `tools/synty/gen_slots.py`; dine `scene/scale/offset/rotation_y` bevares).
* `data/art/vendor_suggestions.json` — pakke-/navneforslag pr. slot (unverified).
* `data/art/animation_sets.json` — rigfamilier, clipnavne, kontakttider, nøgleord.
* `data/art/palette.json` — proxyfarver.
* `data/art/synty_choices.json`, `data/art/slot_scenes.json` — dine valg og byggerens mapping (opstår ved første import).
* `docs/ASSET_PLAN.md` — tabel over alle slots med forslag; `docs/SCENE_ASSEMBLY.md` — placering i kampscenen.
