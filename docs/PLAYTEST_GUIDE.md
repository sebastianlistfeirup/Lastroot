# LASTROOT · Spiltestguide (LR-27 / LR-31)

Til testere og til projektejeren. Alt data bliver på testerens egen maskine, indtil testeren selv sender filen.

## Sådan spiller du som tester

1. **Hent spillet**
   - Desktop: kør den build, du har fået (Windows `Lastroot.exe` eller Linux `Lastroot.x86_64`).
   - Web: åbn det link til webudgaven, du har fået af projektejeren (kræver en nyere desktopbrowser; telefon i portræt virker, men er mindre afprøvet).
2. **Start et nyt løb.** Første gang tilbydes "Sådan spiller du" — se den, hvis du har lyst; det er en del af testen, om spillet kan forstås uden hjælp. Prøv gerne begge champions over flere løb.
3. **Spil som du ville** — der er ingen rigtige eller forkerte valg. Spillet gemmer efter hver handling; du kan altid lukke og fortsætte.
4. **Efter hvert løb** (sejr eller nederlag) vises resultatskærmen med et lille, valgfrit spørgeskema:
   - "Hvordan var dette løb?" 1–5 stjerner.
   - "Gav prognosen mening?" Ja / Delvist / Nej.
   - Fri tekst (højst 500 tegn): hvad var forvirrende, sjovt eller frustrerende?
   - Tryk "Gem feedback". Du kan også springe det over.
5. **Send data:** Indstillinger → *Spiltestdata* → **Eksportér**. Spillet viser stien til filen `lastroot_playtest_<dato>.json` (i spillets brugermappe under `exports/`). Send den fil til projektejeren (mail, chat eller USB — ingen upload sker fra spillet).
   - På web kan filen ligge i browserens lager; skriv det til projektejeren, hvis du ikke kan finde den (eksport til download fra web er ikke lavet endnu).
6. Vil du starte forfra med en tom log: Indstillinger → *Spiltestdata* → **Ryd** → **Slet** (kun på denne enhed).

## Hvad filen indeholder

Én post pr. afsluttet løb (aldrig dobbelt for samme løb):

- løbs-id, seed, champion, championretning og trin, resultat, vundne kampe
- historik pr. kamp (ture, hjerte før og efter, antal spillede væsner)
- ture i alt, spillede kort, tabt hjerteliv, hjerte til sidst
- relikvier, mutationer, endeligt dæk med opgraderinger
- belønningsslots og deres status (taget / sprunget over)
- buildversion (`SaveCodec.BUILD_ID`), sprog, tidspunkt
- din feedback (stjerner, prognose-svar, fritekst), hvis du gav den

Ingen navne, konti, enheds-id'er eller IP-adresser registreres.

## Hvad projektejeren kigger på (bibel p. 22, "Spiltest og balance")

- **Winrate pr. champion** og om begge champions kan vinde på en normal rute.
- **Tabt hjerteliv** og **turantal** pr. kamp (findes i historikken) — hvor bliver det for svært?
- **Kortvalg:** hvilke kort tages, springes over, opgraderes eller fjernes (dæk + belønningsslots).
- **Forståelse:** mål er at mindst fire af fem eksterne testere forstår prognose og målvalg uden hjælp efter onboarding — se svarene på "Gav prognosen mening?" og fritekst.
- **Oplevelse:** stjerner og fritekst, sammenholdt med hvor i løbet testeren stoppede.
- Botten (`tools/balance/run_balance.gd`) er regressionstest, ikke bevis for sjov; spiltestdata er det, der viser oplevelsen.

## Privatliv

- Alt gemmes lokalt (`user://playtest_log.json` i spillets brugermappe). Spillet har ingen netværkskode og sender intet.
- Testeren bestemmer selv, om og hvornår eksportfilen sendes, og kan rydde loggen når som helst.
- Projektejeren opbevarer modtagne filer fortroligt og bruger dem kun til at forbedre spillet.
