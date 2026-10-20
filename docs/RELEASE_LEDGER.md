# LASTROOT · Release-ledger (LR-33)

Hvad der faktisk ligger i en build, hvor det kommer fra, og hvad der skal tjekkes før hver udgivelse. Kun fakta, der kan ses i repoet; alt andet er markeret **skal verificeres**.

## Hvad der leveres

| Del | Indhold | Kilde / ejer | Licens / rettigheder | Status |
| --- | --- | --- | --- | --- |
| Motor | Godot Engine 4.5.1-stable (official) | godotengine.org | MIT. Licensteksten vises i spillet (Medvirkende) via `Engine.get_license_text()`. Tredjepartskomponenter i Godot har egne licenser (`Engine.get_copyright_info()`); de skal medfølge i en distribueret build. | I brug |
| Kode | `scripts/`, `scenes/`, `tools/`, `tests/` | Projektets egen kode | Projektejerens (Sebastian List Feirup) | I brug |
| Data | `data/definitions/catalog.json` (kort, fjender, relikvier, mutationer, kampe), `data/art/*.json` | Egen, efter udviklingsbiblen | Projektejerens | I brug |
| Oversættelse | `localization/translations.csv` (en, da); danske navne/tekster i kataloget | Egen | Projektejerens | I brug |
| Skrifttype | `assets/fonts/DejaVuSans.ttf` som reservefont til symboler (◆☠✶✚⚔♥) | DejaVu-projektet | DejaVu-fontlicens (Bitstream Vera-afledt, fri brug og distribution); teksten ligger i `assets/fonts/DejaVu_LICENSE.txt` og skal medfølge | I brug |
| Lyd | `assets/audio/placeholder/*.wav` (33 lyde + 3 musikloops, ca. 1,6 MB) | Genereret proceduralt af `tools/gen_placeholder_audio.py` (kun Python-standardbibliotek, ingen samples) | Egen | Pladsholder. Endelige lyde planlagt i `docs/AUDIO_LEDGER.csv` (prompts), ikke produceret |
| Grafik (3D) | Proceduralt byggede proxy-modeller (`scripts/runtime/visual/proxy_builder.gd`) og kodetegnet UI | Egen | Projektejerens | I brug (greybox) |
| Grafik (planlagt) | Synty Studios POLYGON-pakker, PolyPerfect-pakker, Mixamo-animationer (se `docs/ASSET_LEDGER.csv`, `docs/ASSET_PLAN.md`) | Tredjepart | **Skal verificeres pr. pakke**: købsbevis, licenstype (fx om spil-distribution og web-build er tilladt, krav om kreditering, forbud mod at udlevere rå assets). Mixamo kræver Adobe-konto; vilkår skal læses for den konkrete brug. I ledgeren står de som `purchased_unverified` | Ikke importeret. Ingen af disse filer ligger i repoet |
| Referencebilleder | `references/REF_01-05.jpeg` | Fra startpakken (konceptbilleder) | **Må ikke** indgå i en build eller i markedsføring som spilbilleder | Kun internt |

## Tjekliste pr. udgivelse

- [ ] `tools/check.sh` grøn (validatorer, release-tjek, parse, tests, scene-smoke, meta-smoke, oversættelse).
- [ ] `python3 tools/release_check.py --checksums` efter eksport: ingen købte vendorfiler eller hemmeligheder i git, alle presets udelukker interne mapper (inkl. `scenes/tests/`), ingen interne filer i `.pck`, checksums skrevet. Rapport: `evidence/release/release_check.json`.
- [ ] Versionsnummer i `project.godot` (`config/version`) og i build-navnet opdateret.
- [ ] Credits-skærmen viser korrekt hold, motor og status for tredjepartspakker ("planlagt" fjernes først, når pakken faktisk er importeret og licensen tjekket).
- [ ] Godot-licens og tredjepartsoplysninger medfølger (Credits + fil i build-mappen).
- [ ] `DejaVu_LICENSE.txt` medfølger.
- [ ] For hver importeret købt pakke: købsbevis arkiveret, licensvilkår læst og noteret i `docs/ASSET_LEDGER.csv` (`rights_status` = verificeret), rå pakkefiler **ikke** i git eller i build ud over det, licensen tillader.
- [ ] Ingen referencebilleder (`references/`) i build eller butiksside.
- [ ] Pladsholderlyd erstattet eller tydeligt accepteret for denne udgivelse; `docs/AUDIO_LEDGER.csv` opdateret.
- [ ] Gemte spil: en save fra forrige version indlæses (eller afvises med forklaring uden at blive slettet).
- [ ] Eksport kørt og startet på hver målplatform (Windows, Linux, Web); resultat og maskine noteret i `docs/STATUS.md`.
- [ ] Skærmbilleder til butikssiden taget fra den faktiske build (se `docs/STORE_PAGE_DRAFT.md`).
- [ ] Checksums for build-filer skrevet til `evidence/build_checksums.txt` (`release_check.py --checksums`).
