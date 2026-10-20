# LASTROOT · Tilgængelighed

Status for LR-28 (grundarbejde). Gælder menu, championvalg, løbsskærme (belønning, rute, knuder), dæk, resultat, indstillinger, pause, "Sådan spiller du", medvirkende og dialoger. Kampens egne genveje ejes af `scripts/ui/battle/`.

## Det findes nu

| Område | Hvad | Hvor |
| --- | --- | --- |
| Tekststørrelse | 90 / 100 / 115 / 130 %. Skærmene bygges om med det samme. Kort vokser i højden i stedet for at klippe tekst (tjekkes af `card_gallery`). | Indstillinger → Tekststørrelse (`SettingsService.text_scale` → `UiKit.font_scale`) |
| Reduceret bevægelse | Slår pulserende/drivende effekter fra (baggrund, rutekort, portrætter, træ). Kampen holder kameraet stille. | Indstillinger (`SettingsService.reduced_motion`) |
| Animationshastighed | 0,5× / 1× / 2×. Ændrer kun præsentation, aldrig udfald. | Indstillinger og kampens hastighedsknap (`SettingsService.anim_speed`) |
| Sprog | Engelsk (kilde) og dansk; al spillertekst går gennem `Loc.t`/`Loc.field`. `tools/loc_extract.py --check` fejler, hvis en tekst mangler dansk. | Indstillinger → Sprog |
| Lydstyrke | Samlet / musik / lydeffekter, gemmes i `user://settings.cfg`. | Indstillinger |
| Status med tegn + tal | Panser ◆, Gift ☠, Torne ✶, Vækst ✚, angreb ⚔, liv ♥ altid som tegn og tal; farven er kun en ekstra hjælp. Samme tegn på kort, enhedsmærker og i "Sådan spiller du". DejaVu Sans er reservefont, så tegnene også vises på web. | `UiKit.status_glyph`, `CardView`, `UnitBadge` |
| Tilstande uden farve | Valgt kort/valg: ✓-mærke. Ikke spilbart: ✕-mærke på kortet. Opgraderet: "+"-bånd og tekstlinje. Rutekort: ✓ valgt, × ikke valgt, lås for låste knuder, tekst "Vundet/Næste/Vælg/✓ Valgt". Lavt Hjerte: "!" foran tallet. Spærrede handlinger: deaktiveret knap + "✕ årsag" i tekst. Advarsler: "⚠ tekst". | Løbsskærmen, rutekortet, kort |
| Store trykflader | Alle knapper og tryk-mål er mindst 48 logiske px høje (testes i `meta_smoke`); på telefon og tablet er alle aktive mål ≥ 44 enheds-px i begge retninger (testes i `layout_smoke`, også kampens kompakte enhedsmærker). Rutekortets knuder er 64 px. | `UiKit.MIN_HIT` |
| Intet kræver hover | Relikvier, mutationer, Hjerte, Harpiks og ruteknuder forklares ved tryk i et detaljepanel. Valg sker som tryk → bekræft. | `RunHeader`, `RunScreen` |
| Tastatur og gamepad | Synlig fokusring (hvid kant) på knapper, kort og valgfelter. Pile/d-pad/venstre pind flytter fokus, Enter/Mellemrum/A aktiverer, Esc/B/Start går tilbage eller lukker. Fornuftigt startfokus på hver skærm, og fokus bevares, når skærmen bygges om. Efter et kortvalg hopper fokus til "Bekræft". Siderne i "Sådan spiller du" kan bladres med venstre/højre. | `SettingsService.add_pad_ui_events()` tilføjer A til `ui_accept` og B/Start til `ui_cancel` ved opstart (Godot 4.5 har dem ikke som standard); `project.godot` er uændret |
| Portrætlayout | Alle skærme fungerer i 430 logiske px bredde (390×844-telefon) uden vandret scroll. | Skærmbilleder i `evidence/meta_screens/*_phone.png` |

## Verificeret automatisk (LR-28 layout-smoke, oktober 2026)

`scenes/tests/layout_smoke.tscn` (kører i `tools/check.sh`, ca. 40 s headless) åbner hver hovedskærm — menu, championvalg, førstegangsprompt, indstillinger, medvirkende, alle 7 sider af "Sådan spiller du", fire belønningstyper (kort, mutation, champion, relikvie), rute, fire knudetyper, resultat (vundet/tabt), kamp (kamp 1, midt i kamp, boss, prognose-ark i portræt, pausemenu) — ved fire vinduer og tre tekstindstillinger og skriver `evidence/layout/layout_report.json`:

| Vindue | Logisk layout (AppFlow) | Berøring |
| --- | --- | --- |
| 1280×720 | 1920×1080 (samme layout, skaleret ned) | nej |
| 1920×1080 | 1920×1080 | nej |
| 430×932 (telefon, portræt) | 430×932 | ja |
| 1024×1366 (tablet, portræt) | 430×573 | ja |

Tekst: engelsk 100 %, engelsk og dansk ved største valg i Indstillinger (130 %). Med `-- --stress` også 150 %.

Tjek pr. synlig Label/Button/RichTextLabel med tekst: tekst afskåret med ellipse/clip, tekst bredere end sin boks, ombrudt tekst med skjulte linjer, ord der ikke kan ombrydes, og boks uden for skærmen eller en klippende forælder (tilladt kun langs en akse, en ScrollContainer ruller). På berøringsvinduer: hver aktiv knap/tryk-flade ≥ 44×44 enheds-px (logisk px × skalering).

Resultat på dette commit: **0 fejl**; 2 bevidste afkortninger accepteret (kampens bølgetekst og prognose-resuméet i portræt, fuld tekst ét tryk væk); 1 kendt fejl (se nedenfor); enkelte "ord tvangsombrudt"-advarsler (fx "Dækstørrelse" i en smal statistikcelle ved 130 % dansk).

Rettet efter testens fund: logoet "LASTROOT" skubbede menuen ud af telefonen ved stor tekst; menuens kolonne ruller nu på lave portrætvinduer (tablet); versionslinjen ombrydes; sidetælleren i "Sådan spiller du" er kompakt på telefon (Næste-knappen lå uden for skærmen); linjer i Medvirkende stables på telefon; lydstyrkerækker i Indstillinger var for brede; vurderingsstjerner på resultatskærmen ombrydes; handlingsknapper på løbsskærmen ombrydes på telefon; kort i hånden mister billedhøjde (derefter 1 px mindre regeltekst) i stedet for at regeltekst skæres af nederst ved stor tekst; kortnavne måles mod den faktiske bredde; kompakte enhedsmærker er 44 px høje (var 38).

Kendt, ikke rettet: tablet-portræt (430×573 logisk) ved 130 %: Askekronens enhedsmærke i bosskampen placeres over skærmens overkant (3D-projektion; rettes i `BattleScreen._layout_badges_portrait`).

## Ikke testet endnu

- Skærmlæsere (Godot 4.5 har begrænset/eksperimentel AccessKit-understøttelse; vi har ikke afprøvet den, og knapper med kun ikon har endnu ingen tilgængelighedsnavne).
- Rigtige telefoner og tablets (kun testet med logisk 430×932 og 1920×1080 i xvfb). Safe areas/notch er ikke afprøvet.
- Rigtige gamepads (kun simuleret via `InputEventAction`). Ingen fokusnavigation testet med højre pind eller skulderknapper.
- Farveblindhedssimulering (protanopi/deuteranopi/tritanopi) af hele paletten.
- Kontrastmåling (WCAG) af dæmpet tekst (`UiKit.TEXT_DIM`) på paneler.
- Undertekster/visuelle signaler for vigtige lyde (fx bossens ankomst) — lyd bærer i dag ikke information alene, men det er ikke systematisk gennemgået.

## Tjekliste for LR-28

- [ ] Alle skærme kan gennemføres kun med tastatur (menu → championvalg → kamp → belønning → rute → knude → resultat).
- [ ] Alle skærme kan gennemføres kun med gamepad (A/B/d-pad), også pausemenuen i kampen.
- [ ] Fokusringen er synlig på alle fokuserbare elementer og forsvinder aldrig efter en ombygning.
- [ ] Esc/B lukker altid det øverste overlay først og åbner aldrig to ting på én gang.
- [ ] Ingen information kun i farve (gennemgå hvert nyt skærmbillede med gråtone-filter).
- [x] Tekst ved 130 % klippes ingen steder på de testede skærme og vinduer (`layout_smoke`; kendt undtagelse: bossens mærke på tablet-portræt).
- [ ] Alle trykflader ≥ 48 px, også i kampens kompakte portrætlayout. (≥ 44 enheds-px er verificeret af `layout_smoke`; 48 logiske px gælder ikke de kompakte mærker.)
- [ ] Reduceret bevægelse stopper al pulserende/drivende bevægelse og kamerarystelser.
- [ ] Dansk oversættelse komplet (`python3 tools/loc_extract.py --check`).
- [ ] Afprøvning på mindst én rigtig Android-telefon, én iPhone og én iPad (safe areas, berøring, tekststørrelse).
- [ ] Afprøvning med en rigtig Xbox-/PlayStation-controller på desktop og web.
- [ ] Beslut om skærmlæserstøtte (AccessKit) er i scope for v1; hvis ja: navngiv ikonknapper og kort.
