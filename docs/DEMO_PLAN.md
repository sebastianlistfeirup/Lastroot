# LASTROOT · Demoplan (LR-34, forslag)

Et forslag til omfang og bevis for en kort, spilbar demo. Intet her er besluttet; det skal godkendes af projektejeren.

## Omfang (forslag)

- **Kampe:** kamp 1 og kamp 2 (de første to faste kampe fra kataloget).
- **Rute:** én rutegren mellem kamp 1 og 2 (to knudetyper efter den gemte rute).
- **Belønninger:** hele det faste flow efter kamp 1 (Harpiks → kortvalg → mutation) og efter kamp 2 (Harpiks → kortvalg → championretning → relikvie). Demoen slutter med en demo-resultatskærm efter kamp 2 eller efter belønningerne.
- **Champions:** begge, Barkvogteren og Sporevismanden, så begge fraktioner kan prøves.
- **Med:** hovedmenu, "Sådan spiller du", indstillinger (sprog, tekststørrelse, reduceret bevægelse, lyd), pause, gem/fortsæt.
- **Ikke med:** kamp 3-5, Askekronen (kan vises som "kommer" på rutekortet), fuld kortpulje-balance ud over de to kampe.
- **Teknisk:** kræver en demo-grænse i domænet (fx "efter kamp 2 → demo slut") — det findes **ikke** i dag og skal laves af den, der ejer `RunReducer`.

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
- Hvert klip noteres i en optagelsesliste: fil, commit, seed, platform, opløsning.
