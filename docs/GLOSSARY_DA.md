# LASTROOT · Dansk ordliste

Ét ord pr. begreb. Gælder `localization/translations.csv` (spillerens tekster), kortenes regeltekster og al dansk dokumentation til spillere. Kilde: udviklingsbiblens danske termer.

| Engelsk | Dansk | Bemærkning |
| --- | --- | --- |
| run | løb | "Nyt løb", "Løb vundet", "løbet er tabt". Aldrig "run". |
| battle | kamp | "Kamp 3 af 6". |
| turn | tur (flertal: ture) | "Tur 3", "Ture: 12". |
| wave | bølge | |
| Sap | Saftkraft | Altid med stort S, også i tekst. |
| Resin | Harpiks | Altid med stort H. |
| Heart | Hjertet | Bestemt form i tekst og etiketter ("Hjertet 60/60", "Helbred Hjertet 8"). Navn: Verdenshjertet. |
| Roots / Trunk / Crown | Rødderne / Stammen / Kronen | Altid bestemt form med stort begyndelsesbogstav. |
| floor | etage | |
| front | front | "Fronten er ved stammen." |
| Armor | Panser | Stort P, når det er statussen. |
| Poison | Gift | Stort G; "forgiftet" om et mål med Gift. |
| Thorns | Torne | |
| Growth | Vækst | |
| heal / healing | helbrede / helbredelse | Aldrig "heale"/"heling". |
| attack | angreb | |
| HP / max HP | liv / maks. liv | |
| space | plads | "5 plads pr. etage". |
| card / deck | kort / dæk | |
| creature / spell | væsen / besværgelse | |
| ally / enemy | allieret / fjende | |
| champion | champion | Bestemt form: championen. |
| champion path / rank | championretning / trin | |
| camp | lejr | |
| encounter | møde | |
| removal | fjernelse | |
| card reward | kortbelønning | |
| relic | relikvie | Intetkøn: et relikvie. |
| mutation | mutation | |
| forecast | prognose | |
| boss / the Ash Crown | boss / Askekronen | |
| upgrade | opgradere / opgradering | Bydeform uden accent: "Opgrader". |
| skip | spring over | |
| save file / backup | gemmefil / sikkerhedskopi | |
| feedback (spiltest) | svar | "Gem svar". |
| playtest | spiltest | |

## Stil

- Bydeform uden accent: Opgrader, Annuller, Eksporter, Opdater.
- Komma før ledsætninger ("Tryk på et kort, og bekræft derefter").
- Knaptekster så korte som muligt ("Vis guiden", "Spring over").
- Tal og pladsholdere (`%d`, `%s`, `{damage}`) bevares præcist; `tools/loc_extract.py --check` afviser ændrede pladsholdere.
- Kortenes regeltekster kommer fra oversættelsestabellen (med pladsholdere), så opgraderede tal også vises korrekt på dansk. Katalogets `text_da` er designspecifikationens kortform og bruges kun, hvis tabellen mangler teksten.
