# LASTROOT — Produktionsplan fra greybox til udgivelse

*Skrevet 19.10.2026 i ferie-sessionen. Biblen (`docs/BIBLE.md`) er baseline; denne plan er den praktiske rækkefølge. Tidsangivelser er planlægningsintervaller, ikke løfter (bibel s. 23).*

## 0. Spilleregler for hele produktionen

1. **Reduceren bestemmer, alt andet viser.** Grafik, animation og lyd må aldrig ændre skade, død eller belønning. Prognosen er altid den rigtige kamp på en klon.
2. **Lille og komplet før stort.** Seks kampe, to champions, 24 kort. Ingen nye fraktioner, etager eller meta-progression uden nyt mandat.
3. **Beviser, ikke påstande.** Hver opgave lukkes med `tools/check.sh` grøn og `evidence/<task>/result.json`.
4. **Købte filer i karantæne.** Synty/PolyPerfect/Mixamo-filer committes aldrig (offentligt repo); kun valg og wrappers.
5. **Én koordinator, højst to specialister** med adskilte filområder (bibel s. 26).

## 1. Faser, porte og milepæle

| Fase | Port (bibel s. 23) | Status nu | Hvad mangler |
|---|---|---|---|
| 1 · Fundament | Spilbar første kamp, begge champions, statusser, sand prognose, save/load, native eksport | Alt implementeret og automatisk testet | Menneskelig gennemspilning, Windows-kørsel, rigtig importprøve (LR-08/09/11/12) |
| 2 · Kvalitetsudsnit | Komplet run, 24 kort, 8 relikvier, 4 mutationer, Askekronen, godkendt Synty/PolyPerfect-udsnit + animationer, 100 prognosescenarier | Domæne + UI færdigt, 120 scenarier matcher | Rigtige modeller/klip (LR-13/18), platformspike på telefon (LR-19) |
| 3 · Komplet spil | Polerede flows, rutegrene, championretninger, balance | Flows, how-to-play, rute med kommende bølger, balanceværktøj | Træstage-art (LR-22), alle figurer (LR-23), kortgrafik (LR-24), balance med mennesker (LR-27), tilgængelighed/telefon (LR-28) |
| 4 · Udgivelse | Releasekandidat, savekompatibilitet, referencehardware, demo | Eksportpresets, checksums, credits | Beta, ledger-kontrol, demo/optagelser, RC + rollback (LR-31..36) |

## 2. Værktøjsmatrix

| Værktøj | Bruges til | Input → output | Kvalitetsport |
|---|---|---|---|
| Claude Code / Codex (koordinator) | Arkitektur, regler, tests, integration, release | tasks.json → commits + evidence | `tools/check.sh` grøn |
| Synty (POLYGON Nature, Fantasy Kingdom, Dark Fantasy m.fl.) | Træ, platforme, props, humanoide figurer, askefjender | pakker → `tools/synty/build.sh` → wrappers | Style gate i `asset_gallery.tscn` |
| PolyPerfect (Low Poly Animated Animals m.fl.) | Thornhart (firbenet), evt. svampe/props | pakke → samme kæde | Egne quadruped-klip, ingen humanoid retarget |
| Mixamo | Humanoide klip: idle, summon, attack, cast, hit, death, defend, victory | FBX without skin → `tools/synty/unpack.py` | RigLab: in-place, ingen fodglid, kontaktframe |
| Blender (valgfri) | Hatte/stav/barkplader som attachments, skala-/pivotrettelser | original → bearbejdet GLB + ledger | Originalen bevares; variant registreres |
| ElevenLabs (valgfri) | Endelige lydeffekter og musikstemninger | `docs/AUDIO_LEDGER.csv` prompts → `assets/audio/final/<cue>.ogg` | Lydniveau, ingen klip, licens noteret |
| Billedværktøjer (Gemini/Grok/Meshy, valgfri) | Kun navngivne visuelle huller og konceptreferencer | brief → koncept | Markeres som koncept; aldrig gameplaybevis |
| HeyGen / video (valgfri) | Præsentation/storyboard | — | Aldrig erstatning for optaget gameplay |

## 3. Grafik — rækkefølge og porte

1. **Line-up (LR-13):** begge champions, to normale væsner (Root Sprout, Sporeling), to fjender (Ashling, Coalshield) under samme lys. Godkend skala, silhuet, materialer.
2. **TreeStage (LR-22):** tre platforme, stamme bagved, hjertet øverst. Form først, lys bagefter, props til sidst (REF_05). Hold forreste kant og enhedstal fri.
3. **Alle væsner og fjender (LR-23):** 10 normale væsner, 2 champions, 5 fjender + Askekronen. Genbrug få rigfamilier med egne attachments og farver.
4. **Kortgrafik (LR-24):** portrætter renderet fra de godkendte modeller; teksten forbliver rigtig tekst.
5. **Mutationer synlige (LR-22):** M01 rødder, M02 stamme, M03 kroneblomster, M04 hjertelys.

Proxy → rigtig model: skriv wrapperens sti i `data/art/asset_slots.json` (eller lad `build.sh` gøre det). Koden ændres ikke.

## 4. Animation

Minimumsbibliotek pr. humanoid: idle, summon, attack/cast, hit, death, defend, victory (bibel s. 19). Firbenede: egne idle/attack/hit/death. Alle klip in place; flyt/opstigning tweenes mellem faste anchors. `UnitAnimator` afspiller `lr/<state>` og falder tilbage til proceduremæssig tween, hvis et klip mangler — flowet kan aldrig låse. Godkend i `rig_lab.tscn` og i rigtig kamp (2× og skip skal give samme slutbillede; testet i scenesmoke).

## 5. Lyd og musik

36 cues er koblet til spillet med procedurelle placeholders (`assets/audio/placeholder/`). Endelige filer lægges i `assets/audio/final/<cue>.ogg` og bruges automatisk. Prompts og beskrivelser: `docs/AUDIO_LEDGER.csv`. Musik: menu, kamp, boss (rolige loops; kampens rytme er turbaseret).

## 6. Balance og spiltest

- Værktøj: `tools/balance/run_balance.gd` (greedy + casual bot, eksperimentflag på en kopi af kataloget). Noter og målte varianter: `docs/BALANCE_NOTES.md`.
- Observation: baseline er for let (casual-bot vinder ~73 %). Forslag: fjende-HP ×1,3 — afprøv med mennesker først.
- Spiltest (bibel s. 22): fem eksterne testere; mindst fire skal forstå prognose og målvalg efter onboarding. Mål antal forsøg, sejrsrate, tabt hjerteliv, turantal, kortvalg.

## 7. UI, tilgængelighed og platforme

- Desktop 1920×1080 er første platform. Portræt 390×844 og iPad 768×1024 er prototype; test på fysisk enhed (web-buildet er klar: Artifact "Lastroot Playtest").
- Indstillinger: sprog (en/da), tekststørrelse, reduceret bevægelse, animationshastighed, lydstyrker. Information bæres altid af glyf + tal, aldrig kun farve.
- Hitflader ≥ 48 logiske px; ingen regel kræver hover eller højreklik.

## 8. Ydelse

- Prognose: p95 1,6 ms på containeren (mål < 50 ms) → `evidence/perf/forecast_latency.json`.
- Mål på referencemaskinen: 1080p/60 fps, p95 frame ≤ 16,7 ms; web/mobil ≥ 30 fps med reduceret lys/partikler. Software-rendering i containeren er ikke en måling.

## 9. Udgivelse

Premium singleplayer med gratis demo er en hypotese (bibel s. 22). Før offentlig upload: ren checkout, savekompatibilitet (`fixtures/`), credits/licenser (Godot MIT, DejaVu, Synty/PolyPerfect/Mixamo-vilkår), checksum, versionsnoter, forrige kandidat bevaret. Offentlig storeupload er en særskilt handling efter din godkendelse.

## 10. Forslag til de første uger efter hjemkomst

| Uge | Fokus | Port/afslutning |
|---|---|---|
| 1 | Spil kamp 1-2 selv; Windows-build; import af første Synty/PolyPerfect-udsnit; line-up | Fase 1-port (LR-08..12) |
| 2 | Træstage-art og mutationer; Mixamo-klip til champions; balance-beslutning efter egne runs | LR-13, LR-22 startet |
| 3 | Alle figurer og fjender; kortportrætter; lyd-pass | LR-18, LR-23, LR-24 |
| 4 | Spiltest med 3-5 personer; ret de største friktioner; telefontest | LR-27, LR-28; fase 2-port |
| 5+ | Polering, beta, demo, releasekandidat | Fase 3 → 4 |

## 11. Risici for planen

Se `docs/RISKS.md`. De største: visuel kvalitet kan først godkendes med rigtige assets på rigtig skærm; balance kræver mennesker; Thornhart kræver en firbenet rig.
