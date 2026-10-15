# scripts/map_pipeline/ — DESTRUCTIVE one-shot map builders

> **Do not run any script here to "inspect" or "test" something.**
> Every script is an `extends SceneTree` batch job that loads a scene/asset,
> mutates it, and **overwrites the file on disk** via `ResourceSaver.save`.
> Running one again re-applies an already-applied edit to the current map
> (duplicate nodes, lost hand edits, broken collisions).

These are kept as a historical record of how `scenes/barangay_court.tscn` was
built. To change the map today, **edit `scenes/barangay_court.tscn` directly**
(Godot editor or careful text edit) and run the gate.

Per-script table (what it overwrites, what it did): [`docs/pipelines/map_pipeline.md`](../../docs/pipelines/map_pipeline.md).

If you truly must re-run one (e.g. rebuilding props from `imported_models/`):
1. Commit or stash first so `git diff` shows exactly what changed.
2. `& $env:GODOT --headless --path . -s scripts/map_pipeline/<name>.gd`
3. Review the diff of the output file, then run the integration gate.
