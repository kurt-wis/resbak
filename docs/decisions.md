# Decision log

Short, dated, newest first. Add an entry when you make a choice that a future reader
would otherwise reverse by accident.

## 2026-10-15: Agent-friendly repo reorganization
- `scripts/` is split into `runtime/` (game code), `tests/` (gate + `legacy/`), and `map_pipeline/` (destructive one-shot builders). **Why:** the scene-overwriting batch scripts sat next to gameplay code with nothing marking them.
- Raw character sources moved from the repo root to `source_art/` (Godot-ignored). The `.blend` moved from `blender/`. The `tools/*.py` paths are now repo-relative.
- `AGENTS.md` was rewritten as a lean routing manual; `CLAUDE.md` imports it. Detailed facts now live in `docs/` (status, architecture, pipelines, glossary).
- The `legacy/verify_*.gd` scripts were found failing on the current map. They're kept for history and are not in the gate.
- Git LFS is enabled for `*.glb *.png *.jpg *.blend *.res`, with no history rewrite.

## 2026-10-14: Batang Hamog moveset
- Removed the `Slide` (baseball slide) and `Dash` (shoulder roll) clips. The gate asserts they're absent by exact name. Authored `Harurot`, `Lusot_Slide`, and `Lusot_Vault` in `tools/build_hamog_moveset.py`.
- Shift became Harurot, so the playtest has no sprint. Harurot recovery always plays Walking, never Running. **Why:** the hunched run pose read badly as a recovery.

## 2026-10-14: Design doc migration
- `AGAWAN BASE IDEA.md` was replaced by `docs/RESBAK.md`: the 3.8 MB embedded image was removed and the name no longer has spaces. Per-character numbers live in `docs/characters/`, and the dossiers win on numeric conflicts.
