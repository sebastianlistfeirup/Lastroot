# Capability-matrix (miljøaudit, LR-01)

Registreret 19.10.2026 i den autonome ferie-session (cloud-container, Linux x86_64, 4 kerner, 15 GB RAM, ingen GPU, ingen fysisk skærm).

| Værktøj / service | Status | auth_mode | Tilladte handlinger | Input → output | Bemærkning |
|---|---|---|---|---|---|
| Godot 4.7.1 (Linux) | available | — | import, tests, scenetests, eksport | projekt → builds/evidence | Officiel binær hentet fra GitHub releases. Headless + Xvfb. |
| Export templates 4.7.1 | available | — | Linux, Windows, Web (no threads) | projekt → `.x86_64` / `.exe` / web | macOS/Android/iOS ikke installeret. |
| Xvfb + Mesa llvmpipe | available | — | screenshots (`DebugCapture`) | scene → PNG | Softwarerendering i GL Compatibility. Visuel kvalitet ≠ målmaskine. |
| Synty-pakker | **unavailable her** | købt af ejeren | — | — | Ingen filer i containeren. Alle visuals er registrerede proxies (VisualSlots). Importkæden er klar i `tools/synty/`. |
| PolyPerfect-pakker | **unavailable her** | købt af ejeren | — | — | Samme som Synty. |
| Mixamo | unavailable | ejerens Adobe-konto | — | — | Retarget-kæden forventer FBX "without skin" pr. klip. |
| Blender | unavailable | — | — | — | Ikke nødvendigt for FBX-sporet i Godot 4.5. |
| ElevenLabs / billed-/videoværktøjer | unavailable | — | — | — | Lokale procedurelle placeholderlyde. |
| Eksterne spiltestere | unavailable | — | — | — | Playtest registreret som udestående (bibel s. 22). |
| Windows-maskine | unavailable | — | — | — | Windows-build er krydseksporteret, ikke kørt på Windows. |
| Fysisk telefon/iPad | unavailable | — | — | — | Portrætlayout kun testet i emulerede vinduesstørrelser (ikke fysisk test). |
| GitHub (repo) | available | session-token | push til `main` | commits | sebastianlistfeirup/Lastroot |
| GENESIS ARK (søsterprojekt) | available (read) | offentligt repo | læse/kopiere mønstre | — | Synty-importkæde, check.sh og overdragelsesformat genbrugt som skabelon. |

Et abonnement beviser ikke API-adgang. Ingen nøgler i kode, screenshots eller prompts.
