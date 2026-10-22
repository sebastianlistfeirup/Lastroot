# Upstream

Vendored from https://github.com/undeadpickle/image-to-3d-rebuild at commit `2b6645e`
(MIT licence, see `LICENSE`, © 2026 undeadpickle). Unchanged except:

- left out `media/` and `docs/` (demo video, GIF, sample GLB/textures; ~MBs, not needed to run);
- left out `scripts/approver_mcp.py` (auto-approves permission prompts in headless runs).
  Lastroot runs this workflow interactively; approve paid generations in the normal prompt.

For LASTROOT, read `.claude/skills/lastroot-gap-asset/SKILL.md` first: it wraps this skill
with the project's rules (Synty EULA, VisualSlots contract, style, ledgers).
To update: re-copy from a newer upstream commit and note it here.
