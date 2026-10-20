# LR-26 · Kritisk lyd har visuelt alternativ (audit 21.10)

Kilde: alle `AudioBridge.play(...)`-kald i `scripts/` (24 cues i brug). For hver lyd, der bærer spilinformation, findes et synligt signal i samme event (`scripts/presentation/battle_presenter.gd`, `scripts/ui/battle/battle_screen.gd`). Lyd kan slås helt fra uden informationstab.

| Lyd | Hvornår | Visuelt alternativ |
|---|---|---|
| `heart_hit` | fjende passerer Kronen | hjertet tager skade (`stage.hurt_heart`), `heart_hit`-popup med tal og ny HP, HUD ♥ opdateres |
| `wave_arrive` | ny bølge | toast "Wave %d of %d arrives on the Roots" + fjender glider ind |
| `boss_arrive` | Askekronen ankommer | boss-intro (kan springes over) + bossbanner fra kampstart + prognose-advarsel |
| `boss_escalate` | tur ≥ 10 | popup "⚔+2" over bossen, angrebstal i mærket stiger |
| `enemy_climb` | fjende klatrer | enheden flyttes til næste etage; prognosen viste "↑ Etage" på forhånd |
| `ui_invalid` | afvist handling | rød årsagstekst i panelet (dansk via `Loc.reason`) |
| `hit` / `armor_block` / `thorns` | skade | popup "-N" / "◆-N" / torne-popup + HP/rustning i mærket |
| `poison_apply` / `poison_tick` | gift | "☠+N" / "☠-N" popup + ☠-tal i mærket |
| `heal` / `growth` | heling | "♥+N" / vækst-popup |
| `death_ally` / `death_enemy` | død | dødsanimation, enheden fjernes, ✝ i prognosen |
| `victory` / `defeat` | kampslut | resultatskærm med tekst |
| `unit_summon`, `card_play`, `ui_*`, `music_*` | feedback/stemning | ingen information alene i lyden |

Kendt undtagelse: med "Spring animation over" vises boss-intro ikke, men bossbanneret og prognosen gør stadig opmærksom på bossen.
