# Værktøjer

Plan- og katalogvalidator bruger kun Python-standardbiblioteket. `python3 tools/render_pdf.py` regenererer PDF og Markdown fra design/bible.json og references. Kræver reportlab, pypdf, Pillow og DejaVu-skrifter; tilpas fontsti på andre OS. Den medfølgende PDF kan bruges uden generatoren.

Godot-testfiler og exportpresets implementeres i LR-opgaverne. Disse Python-scripts udgiver ikke noget og driver ikke en baggrundsagent.

- `tools/record_clip.sh <navn> <WxH> -- <args>`: optager rigtigt gameplay med Movie Maker under Xvfb (`scenes/tests/record_clip.tscn` + AutoDriver) og koder til `evidence/video/<navn>.mp4` + log. Se `evidence/video/README.md`.
- `tools/web_demo_check.js`: starter "Web Demo"-eksporten i headless Chromium og gemmer titelskærmen (`evidence/demo/`).
