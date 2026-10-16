# Decision log

Short, dated, newest first. Add an entry when you make a choice that a future reader
would otherwise reverse by accident.

## 2026-10-16: The GDD is the single design source of truth
- `docs/design/RESBAK_GDD.md` (with `RESBAK_GDD.pdf`, the same text) is now the only design doc. It is written as a precise spec for agents: numbers, states, tick order and scope. **Why:** the old design docs (summary, dossiers, rules spec) disagreed with each other and with the team's latest decisions (Sigla tag rule, no sprint or stamina, Tutoy, rescue by touch, no flag).
- The superseded docs moved to `docs/archive/` unchanged. Don't implement from them.
- Removed the Meshy hero GLBs that had been copied into the repo root, with the textures and `.import` files Godot generated from them. The originals stay in `source_art/heroes/` (Godot-ignored). Put raw sources there, never in the root. `docs/` now has a `.gdignore`, and PDFs go through Git LFS.
- The GDD is edited in the team's design workspace and re-exported here. Don't hand-edit `docs/design/`; ask for a GDD change instead, and note design and code gaps in `status.md`.

## 2026-10-16: Nathan's candy is "Kimkim", not Mik-Mik
- The docs renamed Nathan's powdered-milk candy from Mik-Mik to **Kimkim**. **Why:** Mik-Mik is a real trademark. Don't reintroduce the real name in docs, assets, textures, or code identifiers.

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
