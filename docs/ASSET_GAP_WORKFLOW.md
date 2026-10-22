# LASTROOT · Arbejdsgang for manglende assets (billede → AI-scan → Godot-genopbygning)

*Ejerens beslutning 22.10 (D36): mangler der et asset, prøver vi denne arbejdsgang før vi køber eller beholder en pladsholder.*
Kilde: skill'en [undeadpickle/image-to-3d-rebuild](https://github.com/undeadpickle/image-to-3d-rebuild) (MIT), vendoreret i `.claude/skills/image-to-3d-rebuild/` (commit `2b6645e`, se `UPSTREAM.md`). Lastroot-reglerne står i `.claude/skills/lastroot-gap-asset/SKILL.md` og går forud for den generelle skill.

## Arbejdsgangen (som i opslaget, tilpasset Lastroot)

1. **Mål og detaljer:** hvilken slot (`data/art/asset_slots.json`), rigtig størrelse i meter, hvilke dele bevæger sig, hvilke animationstilstande (idle, attack …), budget for genereringer.
2. **Billede af objektet:** nyt billede genereret fra en tekstprompt (fx GPT Image / Higgsfield), ét objekt, centreret, 3/4-vinkel, neutral baggrund, POLYGON-lavpoly-stil og Lastroots palet. **Aldrig** et Synty/PolyPerfect-billede eller -screenshot som input (Synty EULA §1.4).
3. **Grov 3D-model:** billedet i Meshy (nyeste, fx Meshy 7 via Higgsfield MCP eller Meshy-API'et) eller Tripo. Pris-preflight, præcis det antal genereringer du har godkendt, aldrig genindsend efter timeout.
4. **Ind i Godot:** scannet lægges i `assets/generated_src/<slot>/` (gitignored) og renderes fra 4 vinkler; `measure_scan.py` måler proportioner.
5. **Claude genopbygger/optimerer i Godot:** en ren procedural model (`ProcBuilder`) med scannet som målestok — lavpoly, facetteret, 2–5 materialeklasser, inden for poly-budgettet. Scannets maling kan bages på (valgfrit, ≤ 50 % så det stadig ligner POLYGON-stilen).
6. **Animation og tweaks:** du beskriver bevægelsen; Claude skriver GDScript/AnimationPlayer-klip (`LRAnimations`, bibliotek `lr`, én pr. tilstand). Disneys 12 principper på **50 %**: optakt, hurtig handling, slag-frame, efterslæb, organisk tilt — aldrig lineært, aldrig tegnefilm. Kontakttider: angreb 0,30 s, magi 0,38 s.
7. **Preview:** 3D-preview i Godot (galleri/RigLab/rigtig kamp) + et mobilvenligt web-preview som Claude-artifact, og en kort demovideo.
8. **Ind i spillet:** `"scene": "res://art/generated/<slot>/<slot>.tscn"` på slotten; `synty_selection.json` får `"decision": "generated"`. Ledger-række + beviser i `evidence/gap_assets/<slot>/`.

Animationer og assets er **kun præsentation**: de ændrer aldrig regler, skade, død, belønning eller tidspunkter for udfald.

## Kandidater (fra `data/art/synty_selection.json`, prioriteret)

| # | Slot | Nu | Hvorfor denne arbejdsgang | Bemærkning |
|---|---|---|---|---|
| 1 | `unit.B04` Thornhart (firbenet bark-hjort med tornegevir) | needs_download (PolyPerfect Animated Animals) | Ingen ejet firbenet; spar et køb | Egen firbenet rig med idle/summon/attack/hit/death/move |
| 2 | `unit.B06` Old Oak (treant) | needs_download (Fantasy Rivals) / Demon-fallback | Treant passer bedre end en dæmon | Humanoid-agtig; kan bruge Synty-klip *hvis* rigget følger Synty-navne, ellers egne klip |
| 3 | `stage.heart` Træets hjerte | keep_proxy | Højeste visuelle prioritet (REF_05) | Skadestilstande skal bevares (revner, glød); emissive turkis |
| 4 | `stage.trunk` stammesegment | keep_proxy | Ejede træer er hele træer | Skal passe præcist til tre etager |
| 5 | `mutation.M01` ekstra rødder | keep_proxy | Rødder langs etagekanten | Kun visuelt |
| 6 | `stage.floor_*` etager | keep_proxy | Kun pynt; spilbar flade skal være præcis plan på y=0 og 11,6 m bred | Genopbygningen må ikke ændre fladen |

Effekter (`fx.*`) bliver i `fx_builder.gd` — ikke denne arbejdsgang.

## Krav før første kørsel (ved hjemkomst)
- Adgang til en 3D-generator: **Higgsfield MCP** forbundet i Claude (eller Meshy-API-nøgle i en `.env`, gitignored) og en billedgenerator.
- Python-pakker til bagning: `pip install numpy scipy pillow xatlas` (kun til trin 5, valgfrit).
- ffmpeg til demovideo (valgfrit).
- Prøv **én lille ting først** (fx `stage.heart` eller Thornhart) med 1–2 godkendte genereringer.

## Prompt til Claude/Codex (kopiér)
```
Brug skill'en lastroot-gap-asset (.claude/skills/lastroot-gap-asset/SKILL.md) til slot <slot_id>.
Mål: <kort beskrivelse, størrelse i meter, bevægelige dele, tilstande>.
Lav først et referencebillede i Lastroots POLYGON-stil (ingen Synty-billeder som input).
Generér med nyeste Meshy via Higgsfield MCP. Jeg godkender <N> genereringer — stop ikke for at spørge.
Genopbyg i Godot efter Lastroot-reglerne, animér med Disney-principper på 50 %,
sæt den ind i spillet via VisualSlots, vis mig et web-preview (artifact) og en battle-capture,
kør tools/check.sh og commit.
```
