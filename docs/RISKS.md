# Risici

| ID | Risiko | Påvirker | Status / næste handling |
|---|---|---|---|
| K1 | Visuel kvalitet og rigs kan ikke bevises headless; alle figurer er proxies. | Fase 1-port (visuel kontrol), LR-11, LR-13, LR-18 | Åben. Kør `tools/synty/build.sh` med de købte pakker, åbn RigLab og AssetGallery, godkend line-up. |
| K2 | Windows-build er krydseksporteret, ikke kørt på Windows. | LR-12 | Åben. Kør `builds/windows/Lastroot.exe` på referencemaskinen; registrér fps/p95. |
| K3 | Balance er sandsynligvis for let (bot 40/40). | LR-27 | Åben. Menneskelig spiltest med begge champions før talændringer; brug `tools/balance/run_balance.gd` før/efter. |
| K4 | Portrætlayout er en prototype; badges bliver tætte ved fulde etager. | LR-28 | Åben. Test på fysisk telefon; overvej zoom på etage ved målvalg. |
| K5 | Web-build på telefon er kun browser-emuleret. | LR-19 | Åben. Fysisk test på telefon/iPad; rapportér separat fra desktop. |
| K6 | Ingen menneskelig gennemspilning optaget endnu. | LR-09, LR-11, LR-12 | Åben. Én optaget runde af kamp 1 med hver champion. |
| K7 | Thornhart kræver quadruped-rig (ikke humanoid retarget). | LR-23 | Åben. PolyPerfect-dyr eller tydelig proxy-opgave. |

Registrér reproduktion, påvirket gate og næste handling ved konkrete blokeringer.
