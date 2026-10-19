# LASTROOT - Godot startpakke v2

Læs hele docs/BIBLE.md eller den medfølgende PDF. Dette er en færdig udviklingsspecifikation og referencepakke, ikke et allerede implementeret spil.

## Start

1. Læs AGENTS.md og gældende lokale repositoryregler. Auditér eksisterende LASTROOT-arbejde og bevar det.
2. Vælg et selvstændigt repository eller en migrationsbranch i det eksisterende. Ingen afhængighed af de andre spil.
3. Kør `python3 tools/validate_plan.py --next` og `python3 tools/validate_catalog.py`.
4. Start LR-01. Implementér næste READY-opgave, test, gem beviser, commit og fortsæt.

## Før hjemkomst

Én ansvarlig Codex- eller Claude Code-agent arbejder alene. Den syvdages plan er relativ; hvis hjemkomsten kommer tidligere, skift profil uden at nulstille opgaverne. Første port er en spilbar kamp med begge startchampions, sand prognose, saves og native eksport. Hele runnet er et strækmål, ikke en skjult forudsætning for at afslutte uge 1.

## Efter hjemkomst

Samme repository og save-/domænekontrakter. Auditér Synty, PolyPerfect, Blender og tilgængelige medieværktøjer. Én koordinator kan bruge højst to afgrænsede specialister med separate worktrees/filområder. Åbne faseporte skal stadig bestås.

## Vigtige valg

- Godot 4.x, GDScript og rigtig Control-UI. TypeScript/Three.js-appendiks i archive er historik.
- Native desktop først. Touchlayout bevares; Godot-web og fysisk telefon/iPad verificeres særskilt.
- Kamp beregnes rent og deterministisk. 3D/animation viser eventlisten og må ikke ændre skade eller belønning.
- 24 kort inklusive to champions, otte relikvier, fire mutationer, fem normale kampe og én boss.
- Fem faktiske referencebilleder medfølger. REF_06-10 er produktionsbriefs, ikke færdige billeder.
- Katalog- og planvalidator er dokumentværktøjer. Ingen Godot-tests er påstået kørt.

Tag reversible beslutninger selv og fortsæt uden løbende spørgsmål. Gem STATUS, DECISIONS, tasks og evidence efter hver opgave. Lang kørsel kræver aktiv runtime; checkpointet gør næste session i stand til at fortsætte.
