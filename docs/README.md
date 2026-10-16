# RESBAK docs index

## Start here, by task

| If you're… | Read, in order |
| ---------- | -------------- |
| New to the project | [`../AGENTS.md`](../AGENTS.md) → [`status.md`](status.md) → [`design/RESBAK_GDD.md`](design/RESBAK_GDD.md) (Game at a glance, Core rules) → [`glossary.md`](glossary.md) |
| Implementing a skill / passive | GDD § Characters → [`architecture.md`](architecture.md) → [`status.md`](status.md) |
| Implementing game rules (tag, jail, rescue, win) | GDD § Core rules and § Player states and timing → GDD § Technical notes for Godot (tick order) → [`architecture.md`](architecture.md) § "Not yet in code" |
| Checking whether a feature is in scope | GDD § What ships when |
| Editing the map | GDD § Maps → [`pipelines/map_pipeline.md`](pipelines/map_pipeline.md) (edit the scene directly; never re-run the pipeline scripts) |
| Building / animating a character | [`pipelines/blender.md`](pipelines/blender.md) → [`../tools/README.md`](../tools/README.md) |
| Adding props / textures | [`pipelines/assets.md`](pipelines/assets.md) |
| Wondering "why is it like this?" | [`decisions.md`](decisions.md) |

## All docs

**Design (intent)**
- [`design/RESBAK_GDD.md`](design/RESBAK_GDD.md): the game design document and the only design source of truth. [`design/RESBAK_GDD.pdf`](design/RESBAK_GDD.pdf) is the same text, laid out for people. Exported from the team's design workspace; don't hand-edit.
- [`glossary.md`](glossary.md): Filipino terms → mechanics → code identifiers.

**Reality (what ships)**
- [`status.md`](status.md): implementation matrix plus known design ↔ code gaps.
- [`architecture.md`](architecture.md): scenes, player controller, state machine, input, project settings.
- [`pipelines/`](pipelines/): [blender](pipelines/blender.md) · [map_pipeline](pipelines/map_pipeline.md) · [assets](pipelines/assets.md).
- [`decisions.md`](decisions.md): dated decision log.

**History**
- [`archive/`](archive/): superseded design docs (old summary, character dossiers, rules spec). Kept for reference only. Never implement from them.

## Doc conventions
- Design docs say what *should* exist. Reality docs say what *does*. When code and a reality doc disagree, the code wins: fix the doc in the same change.
- Reference code as `path/to/file.gd` + a symbol name (`try_lusot`), not line numbers, because line numbers drift.
- Don't copy numbers that already live in code or the GDD. Link to them instead.
