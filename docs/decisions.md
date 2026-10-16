# Decision log

Short, dated, newest first. Add an entry when you make a choice that a future reader
would otherwise reverse by accident.

## 2026-10-16: docs/RESBAK.md is the spec; the match runs on a host tick
- `docs/RESBAK.md` (the finalized concise spec) replaces `docs/design/RESBAK_GDD.md` as the single design source of truth. `docs/design/` is gone.
- **Match architecture:** one `MatchHost` runs the spec § 12 tick order at 60 ticks/s; players and bots both produce `InputFrame`s and gameplay never reads `Input`. **Why:** LAN play only has to send frames and draw snapshots, and tests can step exact ticks.
- **Numbers live in data:** `data/tuning.tres` (shared) and `data/heroes/<id>.tres` (per hero, skill values in `values`). **Why:** spec § 1 says starting values are named constants, never hard-coded.
- **Heroes' clips come from Meshy:** each hero GLB was auto-rigged by Meshy and given preset animations (plus two text-to-motion clips), then retargeted onto our rigs in `tools/build_heroes.py`. **Why:** Mixamo needed a sign-in we couldn't do; Meshy rigged the real heroes, so retargets are near-lossless. 147 credits, logged for Form 03 in `docs/pipelines/blender.md`.
- **Base resolution 1920×1080**, borderless fullscreen by default (spec § 10 default and § 12 target).
- **Gate is a suite runner:** `integration_test.gd` runs `scripts/tests/suites/*.gd`, counting failed checks instead of asserting, so a failure exits 1 instead of hanging.
- **Facing:** heroes face their movement while running and turn to the aim when standing, tagging or casting (spec says always face the cursor). Logged as a gap for a team decision.
- Hero bodies are kinematic under Jolt and only move in the physics server on a real physics step; tests that need hero-vs-hero blocking step with a physics frame between ticks.

## 2026-10-16: The GDD is the single design source of truth
- (Superseded the same day by `docs/RESBAK.md`.) `docs/design/RESBAK_GDD.md` became the only design doc: a condensed (~7k words) spec of the team's full GDD, written for agents (numbers, states, tick order, scope). The full GDD is a long PDF kept outside the repo, so it doesn't fill agent context. **Why:** the old design docs (summary, dossiers, rules spec) disagreed with each other and with the team's latest decisions (Unahan tag rule with own-base barrier, no sprint or stamina, Tutoy, rescue by touch, no flag).
- The superseded docs moved to `docs/archive/` unchanged. Don't implement from them.
- Removed the Meshy hero GLBs that had been copied into the repo root, with the textures and `.import` files Godot generated from them. The originals stay in `source_art/heroes/` (Godot-ignored). Put raw sources there, never in the root. `docs/` now has a `.gdignore`.
- The spec is regenerated from the full GDD whenever the GDD changes. Don't hand-edit `docs/design/`; ask for a GDD change instead, and note design and code gaps in `status.md`.

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
