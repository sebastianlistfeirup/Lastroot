# Værktøjer

Plan- og katalogvalidator bruger kun Python-standardbiblioteket. `python3 tools/render_pdf.py` regenererer PDF og Markdown fra design/bible.json og references. Kræver reportlab, pypdf, Pillow og DejaVu-skrifter; tilpas fontsti på andre OS. Den medfølgende PDF kan bruges uden generatoren.

Godot-testfiler og exportpresets implementeres i LR-opgaverne. Disse Python-scripts udgiver ikke noget og driver ikke en baggrundsagent.
