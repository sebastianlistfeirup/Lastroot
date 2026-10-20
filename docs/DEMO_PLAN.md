# LASTROOT · Demoplan (LR-34)

Omfang og bevis for en kort, spilbar demo. Demogrænsen er nu bygget (beslutning D27); resten af planen skal stadig godkendes af projektejeren.

## Omfang (forslag)

- **Kampe:** kamp 1 og kamp 2 (de første to faste kampe fra kataloget).
- **Rute:** én rutegren mellem kamp 1 og 2 (to knudetyper efter den gemte rute).
- **Belønninger:** hele det faste flow efter kamp 1 (Harpiks → kortvalg → mutation). Demoen slutter, så snart kamp 2 er vundet, så belønningerne efter kamp 2 (championretning, relikvie) er ikke med; de nævnes på demo-resultatskærmen som en del af det fulde spil.
- **Champions:** begge, Barkvogteren og Sporevismanden, så begge fraktioner kan prøves.
- **Med:** hovedmenu, "Sådan spiller du", indstillinger (sprog, tekststørrelse, reduceret bevægelse, lyd), pause, gem/fortsæt.
- **Ikke med:** kamp 3-5, Askekronen (kan vises som "kommer" på rutekortet), fuld kortpulje-balance ud over de to kampe.
- **Teknisk (bygget):** `RunReducer.new_run(seed, faction, "demo")` afslutter løbet efter `DEMO_BATTLES` = 2 vundne kampe med `phase = "won"` og `result = "demo_complete"`; reglerne er ellers identiske. `GameSession` vælger demotilstand, når buildet har featuren `demo` (eksportpreset "Web Demo").
- **Hvad spilleren ser:** titelskærmen viser et lille "DEMO · de første to kampe"-mærke; efter kamp 2 vises "Demoen er slut" med det, spilleren nåede (rigtige tal), og et ærligt "I det fulde spil"-panel (tre kampe mere og Askekronen, championretning og trin 2, to relikvievalg og en mutation mere, fire valg mere på ruten). Knapper: Nyt løb / Hovedmenu.
- **Spiltestlog:** hver post har `mode` (`full` eller `demo`), så demo- og fuldspilsdata kan adskilles.

## Hvad demoen skal bevise

1. Kernen er forståelig uden forklaring udefra: etager, front, Saftkraft, kort → mål → bekræft.
2. Prognosen er troværdig: det, panelet viser, er det, der sker.
3. Valg betyder noget: kortvalg, mutation, championretning og relikvie ændrer næste kamp mærkbart.
4. Det kører på målplatformene (desktop og web; telefon i portræt) med 48 px trykflader og uden hover.
5. Gem og fortsæt virker midt i en kamp og midt i et belønningsflow uden reroll.

Mål til spiltest (forslag, ikke målt endnu): andel testere der gennemfører kamp 1 uden hjælp, tid til første spillede kort, antal fejlklik på ugyldige mål, svar på "forstod du prognosen?".

## Trailer og billeder: kun fra rigtigt gameplay

- Optag kun fra den faktiske build (eller `godot --path .` på samme commit), aldrig fra konceptbilleder (`references/`) eller håndlavede mockups.
- Brug faste seeds og fixtures (`-- --setup=midbattle --faction=SPORE --seed=3` osv., se `scripts/ui/boot.gd`) for gentagelige optagelser; skriv seed og commit ned for hvert klip.
- Ingen manipulerede tal: belønninger, skade og prognose skal være dem, motoren giver.
- Pladsholdergrafik og -lyd vises som det, de er; tekst som "work in progress" bevares, indtil rigtige assets er importeret.
- Klip må forkortes og sættes sammen, men ikke vise funktioner, der ikke findes i demoen.
- Hvert klip noteres i en optagelsesliste: fil, commit, seed, platform, opløsning. Listen er `evidence/video/README.md` (fire klip: prognose, etagekamp, mutation, Askekronen; optaget med `tools/record_clip.sh`).

## Demo-build check (20.10.2026, commit `6e98bfb`)

Bevis: `evidence/demo/result.json` (status **PARTIAL**), logs `evidence/demo/s1..s3_*.json`, `evidence/demo/demo_complete_1280x720.png`, `evidence/demo/demo_end.mp4` (21,8 s: slutningen af kamp 2 → "End of the demo"), `evidence/demo/web_demo_title.png`.

- **Web Demo eksporteret:** `godot --headless --path . --export-release "Web Demo" builds/web_demo/index.html` (exit 0). `index.pck` indeholder `_custom_features = demo`. `node tools/web_demo_check.js` (headless Chromium, swiftshader): titelmenuen nås efter 27 s uden scriptfejl og viser "DEMO · first two battles". Demoen er *ikke* spillet igennem i browseren.
- **Linux-demo:** der findes intet Linux-demo-preset i `export_presets.cfg`. Til kontrollen fik en kopi af commit'et (uden for repoet) to ekstra presets, "Linux QA" og "Linux Demo QA" (`custom_features="demo"`), magen til "Linux" bortset fra at `scenes/tests/` ikke er udelukket, så QA-driveren `scenes/tests/record_clip.tscn` følger med. Driveren starter et løb ad spillerens vej (`GameSession.new_run`) og lader botten spille via `AutoDriver`; når løbet slutter, trykkes slutbannerets knap, og resultatskærmen vises.
- **Demogrænsen virker i det eksporterede demobuild:** løb `mode=demo`; botten bad om 3 kampe, men løbet sluttede efter 2 vundne (`phase=won`, `result=demo_complete`, 60,7 s spilletid) med skærmen "End of the demo", panelet "In the full game" og rigtige tal (2/2 kampe, 6 ture, 20 kort). Alle 6 tur-afslutninger matchede prognosen.
- **Save i dag (læst i `scripts/autoload/save_service.gd`, ikke ændret):** demo og fuldt spil bruger *samme* filer, `user://saves/run.json` + `run.backup.json` (desktop: `~/.local/share/godot/app_userdata/LASTROOT/saves/`; samme projektnavn, ingen egen brugermappe). Demotilstand er kun feltet `run.mode = "demo"`.
  - Et nyt demoløb **overskriver et fuldt løb og dets backup** (kørsel s1 → s3: `LR-00000005 mode=full` → `LR-00000007 mode=demo`; hverken `run.json` eller `run.backup.json` indeholder det fulde løb bagefter). I menuen kommer først dialogen "Start a new run? Your current run will end" — driveren går uden om menuen, men en spiller, der bekræfter "New Run", mister det fulde løb.
  - Demobuildet kan **fortsætte et fuldt løb** med Continue (s2: `mode=full` indlæst i demobuildet), og så gælder demogrænsen ikke.
  - Web: `user://` ligger i browserens IndexedDB pr. origin; en Web Demo på samme origin som det fulde web-build vil dele save (udledt af Godots web-platform, ikke testet).
  - **LR-34-kriteriet "Demo kan ikke ødelægge et fuldt run-save" er derfor ikke opfyldt på `6e98bfb`.** En anden agent tilføjer adskilte demo-savestier i `save_service.gd`; kør kontrollen igen bagefter (kommandoerne står i `evidence/demo/result.json`). Forslag: et "Linux Demo"-preset i repoet, og at demobuildet ignorerer et save med `mode=full`.

**Linux Demo-preset (21.10):** `mkdir -p builds/linux_demo && godot --headless --export-release "Linux Demo" builds/linux_demo/LastrootDemo.x86_64` (samme som "Linux" + featuren `demo`). Godot laver ikke mappen selv.
