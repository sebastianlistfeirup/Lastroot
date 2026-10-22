# START HER — LASTROOT

## 0. I morgen: sådan sætter du projektet i gang

**Før du åbner Claude/Codex (≈20 min):**
1. `git clone https://github.com/sebastianlistfeirup/Lastroot` (eller `git pull` på main).
2. Hent de 16 Synty-arkiver fra din SyntyPass-konto **før abonnementet udløber (~16.11.2026)** — liste + sha256 i `docs/HOMECOMING.md` §2. Læg dem *uden for* repoet, fx `C:\LastrootPacks\`.
3. Godot: Lastroot er låst til 4.5.1. Opgradering til 4.7.1 (din Realmrend-version) er testet grøn på grenen `godot-4.7` og venter på dit ja (D35, se `docs/STATUS.md`).

**Første besked til Claude Code** (åbn i repo-mappen og indsæt):
```
Læs START_HERE.md, AGENTS.md, docs/STATUS.md, docs/HOMECOMING.md og docs/REALMREND_LESSONS.md.
Mine Synty-arkiver ligger i <sti>. Kør docs/HOMECOMING.md fra §1: tools/check.sh, doctor,
udpak pakkerne (tools/synty/unpack.py), kør tools/synty/apply_selection.py --archives <sti>
og tools/synty/build.sh, og vis mig asset-galleriet og en kampcapture med de rigtige modeller.
Ret fejl undervejs (én slot ad gangen med tools/synty/focus.py), commit og push små skridt.
Synty/PolyPerfect-filer må aldrig committes. Spørg mig kun ved valg, der er mine
(Godot 4.7.1-opgradering, balance Standard/Svær, assets der skal laves via docs/ASSET_GAP_WORKFLOW.md).
```

**Samme opgave i Codex:** Codex læser `AGENTS.md` automatisk. Brug samme tekst, men tilføj
"skills ligger i `.claude/skills/` — læs SKILL.md-filen direkte, når en opgave matcher".

**Manglende assets (fx Thornhart):** se `docs/ASSET_GAP_WORKFLOW.md` — dér står en færdig prompt til billede → Meshy → Godot-genopbygning (kræver Higgsfield MCP eller Meshy-nøgle).

**Spil først selv 10 min** (LR-08/09): F5 i Godot, kamp 1 med begge champions, prøv Indstillinger → Difficulty → Hard.

---

Hej Sebastian. Dette er overdragelsen fra den autonome ferie-session (19. oktober 2026), bygget på samme måde som GENESIS ARK: Godot (nu 4.7.1, D35), ren domænemotor med tests, greybox-proxies der kan byttes til Synty/PolyPerfect, beviser i `evidence/`. Alt herunder er kørt i containeren; hvad der *ikke* kunne afprøves, står eksplicit.

## 1. Hvad er der?

Et spilbart **greybox-gennemløb** af hele LASTROOT:

1. **Hovedmenu → vælg champion** (Barkvogteren eller Sporevismanden) → nyt run med 12-korts startdeck.
2. **Kampen**: 3D-træ med Rødderne/Stammen/Kronen og det turkise hjerte. Tap kort → tap et oplyst mål (+-plads på en etage, en enhed eller en etage) → **Bekræft**. Tap egen figur for at flytte den. Højre panel er **prognosen**: præcis hvad der sker, når du afslutter turen (samme reducer som den rigtige kamp). Enhedsbadges viser angreb/liv/panser/gift/torne/vækst og forventet ændring.
3. **Alle regler fra biblen**: 24 kort, panser/gift/torne/vækst, FIFO-død, fælles opstigning, 3 bølger pr. kamp, 8 relikvier, 4 mutationer, 4 championretninger i 2 trin, Askekronen (ankring, tur-10-eskalation, nederlag hvis den forlader Kronen).
4. **Runnet**: fem kampe + boss, fast belønningsrækkefølge (R05 → +20 harpiks → kortvalg → mutation/championforbedring + relikvie), rutegren med to knuder (lejr, kort, møde, fjernelse), resultatskærm.
5. **Save/load** efter hver handling: atomisk skrivning, backup, korrupt-/fremtidig-version-håndtering, JSON-eksport/-import, presentation checkpoint (load viser færdigt resultat — intet afregnes igen).
6. **Grafik**: stiliserede low-poly proxies for alle 12 væsner, 6 fjender, træets dele, props og 10 effekter (`scripts/runtime/visual/`). Hver proxy er et *slot*, som skiftes til en købt model uden at røre koden.
7. **Spillet er kun på engelsk** (D34; danske tekster ligger hvilende). Lyd: procedurelle placeholder-cues.
8. **"Sådan spiller du"** (7 illustrerede sider) fra menu og pause, tilbydes automatisk ved første run. Rutekortet viser næste kamps bølger og bossens regler.
9. **Kort med rigtig tekst og portrætter** renderet fra de samme visual slots som kampen (skifter automatisk til Synty/PolyPerfect), 3D-målringe og "fare"-ringe fra prognosen, udtryksfulde proxy-animationer.
10. **Tastatur og gamepad** overalt: i kampen `1-9` kort, `Tab`/pile mål, `Enter` bekræft, `E` afslut tur (pad: LB/RB, D-pad, A, Y). Indstillinger: tekststørrelse, reduceret bevægelse, animationshastighed, lydstyrker.

## 2. Spil det

1. Installér **Godot 4.7.1-stable** (samme som Realmrend; kræves af Synty Dark Fantasy Godot-pakken) (samme version — `docs/VERSION_MATRIX.md`).
2. Åbn mappen i Godot → **F5**. Eller kør `builds/windows/Lastroot.exe` efter eksport (se §5).
3. Mus/touch: tap kort → tap mål → Bekræft (eller tap samme mål igen). `Esc` annullerer/åbner menu. Tastatur/pad: se punkt 10 ovenfor.
   **På telefonen nu:** Artifact "Lastroot Playtest" (https://claude.ai/artifact/BsnV9QwztLZ5haFiHhnAjX) er web-buildet af spillet — virker i telefonens browser, op- eller nedvendt (greybox, kan være tungt på ældre telefoner). `1×/2×/½×` styrer animationshastighed; "Skip animation" springer afspilningen over.
4. Hurtige test-states: `godot --path . -- --setup=boss` (se `AGENTS.md` for alle navne).

## 3. Næste skridt: grafik (LR-11 / LR-13 →)

**Hurtig vej** står øverst i `docs/SYNTY_INTEGRATION.md`: `tools/synty/unpack.py` for hver pakke (Synty, PolyPerfect, en mappe med Mixamo-FBX) → `tools/synty/match.py` → kig `data/art/synty_choices.json` igennem → `tools/synty/build.sh` → F5.

- `docs/ASSET_PLAN.md` — hvilke Synty-/PolyPerfect-pakker og Mixamo-klip der foreslås pr. slot (navnene er søgehints, *ikke* kontrolleret mod dine filer).
- `docs/SCENE_ASSEMBLY.md` — hvor hver del sidder i træet (etager i y = 0 / 4,5 / 9, hjertet øverst, stamme bagved).
- `scenes/tests/asset_gallery.tscn` — **style gate**: alle figurer under samme lys. `scenes/tests/rig_lab.tscn` — én rig: skala, fødder, retning, alle klip.
- **Før/efter:** `tools/capture_all.sh efter_import --compare=proxies_baseline` tager alle screenshots og laver en side med proxies vs. dine rigtige modeller (`evidence/captures/…/compare_proxies_baseline.html`; disse mapper committes ikke).
- Første rigtige import: se afsnit "6b. Første rigtige import" i `docs/SYNTY_INTEGRATION.md` (kæden er prøvet på rigtige FBX-filer, men endnu ikke på en humanoid Synty/Mixamo-fil).
- Thornhart er et firbenet dyr: brug et PolyPerfect-dyr med egne klip, ikke humanoid retarget.
- Editor-docken "Asset-slots" kan slås til i `project.godot` (se `docs/SYNTY_INTEGRATION.md`).

## 4. Kvalitet og beviser

| Lag | Kommando | Resultat på dette commit |
|---|---|---|
| Alt i ét | `tools/check.sh` | validatorer, parse-tjek, tests, scenesmoke, meta-smoke |
| Domæne + prognose | `godot --headless --path . --script res://tests/run_tests.gd` | se `evidence/test_report.json` |
| Kampscene (rigtigt input) | `godot --headless --path . res://scenes/tests/scene_smoke.tscn` | se `evidence/scene_smoke.json` |
| Prognose = virkelighed | 120 gemte scenarier i `fixtures/forecast/` | state-hash og eventrækkefølge matcher |
| Balance (bot) | `godot --headless --path . --script res://tools/balance/run_balance.gd` | `evidence/balance/balance_report_greedy.json` |
| Grafikpipeline | `tools/synty/selftest.sh` | `evidence/asset_pipeline/selftest.json` |
| Screenshots / video | `evidence/shots/`, `evidence/meta_screens/`, `evidence/video/battle1_spore_autoplay.mp4` | Xvfb-software-rendering, ikke din GPU |

## 5. Ærlig status

Se `docs/STATUS.md` (porte, opgaver, tests, blokeringer, næste tre opgaver) og `docs/RISKS.md`. Kort:

- **Fase 1** er implementeret og automatisk testet. Porten er *ikke* erklæret bestået, fordi den kræver ting containeren ikke kan: rigtig import af dine Synty/PolyPerfect-filer (LR-11), Windows-buildet kørt på din maskine og en menneskelig gennemspilning (LR-12).
- Meget af **fase 2** er bygget i domænet (alle 24 kort, relikvier, mutationer, championretninger, rute/økonomi, kamp 2-5 og boss, 120 prognosescenarier). De står som `IN_PROGRESS` med noter i `plan/tasks.json`, fordi faseporten skal bestås først.
- **Balance**: botten vinder alle 40 testruns. Sandsynligvis for let — men tal ændres først efter en rigtig spiltest (D24).

## 5b. Spiltestere

`docs/PLAYTEST_GUIDE.md`: testere spiller (desktop-build eller web), svarer på det lille skema efter hvert løb og sender eksportfilen (Indstillinger → Spiltestdata → Eksportér). Alt bliver på deres egen maskine. Demo-build: eksportér preset "Web Demo" (slutter efter 2 kampe, `docs/DEMO_PLAN.md`).

## 6. Når du kommer hjem (forslag til rækkefølge)

1. `git pull`, åbn i Godot 4.7.1, F5, spil kamp 1 med begge champions (≈10 min). Notér de tre største friktioner.
2. Kør grafik-"Hurtig vej" med dine pakker; godkend line-up i `asset_gallery.tscn` (LR-11/LR-13).
3. Eksportér Windows (`godot --headless --path . --export-release "Windows Desktop" builds/windows/Lastroot.exe`), kør på din maskine, og bed agenten markere LR-12.
4. Derefter: LR-18 (rigtige animationer), LR-27 (balance med mennesker), LR-28 (portræt/telefon).

## 7. Dokumenter

`docs/PRODUCTION_PLAN.md` (plan til udgivelse) · `docs/BALANCE_NOTES.md` · `docs/ACCESSIBILITY.md` · `docs/RELEASE_LEDGER.md` · `docs/DEMO_PLAN.md` · `docs/STORE_PAGE_DRAFT.md` · `README.md` · `AGENTS.md`/`CLAUDE.md` (regler for kodeagenter) · `plan/tasks.json` + `tools/validate_plan.py` · `docs/BIBLE.md` + PDF · `docs/STATUS.md` · `docs/DECISIONS.md` · `docs/RISKS.md` · `docs/VERSION_MATRIX.md` · `docs/CAPABILITY_MATRIX.md` · `docs/ASSET_PLAN.md` · `docs/SYNTY_INTEGRATION.md` · `docs/SCENE_ASSEMBLY.md` · `docs/ASSET_LEDGER.csv` · `docs/ANIMATION_LEDGER.csv` · `docs/AUDIO_LEDGER.csv` · `archive/` (startpakkens originaler)
