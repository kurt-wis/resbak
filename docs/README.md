# RESBAK docs index

## Start here, by task

| If you're… | Read, in order |
| ---------- | -------------- |
| New to the project | [`../AGENTS.md`](../AGENTS.md) → [`status.md`](status.md) → [`RESBAK.md`](RESBAK.md) (§ 1 and § 2) → [`glossary.md`](glossary.md) |
| Implementing a skill / passive | spec § 4 Characters → [`architecture.md`](architecture.md) → [`status.md`](status.md) |
| Implementing game rules (tag, jail, rescue, win) | spec § 2 Core rules → spec § 12 Technical (tick order) → [`architecture.md`](architecture.md) (MatchHost, systems) |
| Checking whether a feature is in scope | spec § 1, What ships when |
| Editing the map | spec § 5 Maps → [`pipelines/map_pipeline.md`](pipelines/map_pipeline.md) (edit the scene directly; never re-run the pipeline scripts) |
| Building / animating a character | [`pipelines/blender.md`](pipelines/blender.md) → [`../tools/README.md`](../tools/README.md) |
| Adding props / textures | [`pipelines/assets.md`](pipelines/assets.md) |
| Wondering "why is it like this?" | [`decisions.md`](decisions.md) |

## All docs

**Design (intent)**
- [`RESBAK.md`](RESBAK.md): the design spec, condensed from the team's full GDD (a long PDF kept outside the repo). The only design source of truth. Don't hand-edit.
- [`glossary.md`](glossary.md): Filipino terms → mechanics → code identifiers.

**Reality (what ships)**
- [`status.md`](status.md): implementation matrix plus known design ↔ code gaps.
- [`architecture.md`](architecture.md): scenes, player controller, state machine, input, project settings.
- [`pipelines/`](pipelines/): [blender](pipelines/blender.md) · [map_pipeline](pipelines/map_pipeline.md) · [assets](pipelines/assets.md).
- [`decisions.md`](decisions.md): dated decision log.
- [`plans/`](plans/): dated implementation plans for in-flight work. Delete a plan once it has fully shipped.

**History**
- [`archive/`](archive/): superseded design docs (old summary, character dossiers, rules spec). Kept for reference only. Never implement from them.

## Doc conventions
- Design docs say what *should* exist. Reality docs say what *does*. When code and a reality doc disagree, the code wins: fix the doc in the same change.
- Reference code as `path/to/file.gd` + a symbol name (`try_lusot`), not line numbers, because line numbers drift.
- Don't copy numbers that already live in code or the spec. Link to them instead.
