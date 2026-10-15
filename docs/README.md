# RESBAK docs index

## Start here, by task

| If you're… | Read, in order |
| ---------- | -------------- |
| New to the project | [`../AGENTS.md`](../AGENTS.md) → [`status.md`](status.md) → [`RESBAK.md`](RESBAK.md) → [`glossary.md`](glossary.md) |
| Implementing a skill / passive | the character's dossier in [`characters/`](characters/) → [`architecture.md`](architecture.md) → [`status.md`](status.md) |
| Implementing game rules (tag, jail, rescue, win) | [`gameplay/agawan_base_rules.md`](gameplay/agawan_base_rules.md) → [`architecture.md`](architecture.md) § "Not yet in code" |
| Editing the map | [`pipelines/map_pipeline.md`](pipelines/map_pipeline.md) (edit the scene directly; never re-run the pipeline scripts) |
| Building / animating a character | [`pipelines/blender.md`](pipelines/blender.md) → [`../tools/README.md`](../tools/README.md) |
| Adding props / textures | [`pipelines/assets.md`](pipelines/assets.md) |
| Wondering "why is it like this?" | [`decisions.md`](decisions.md) |

## All docs

**Design (intent)**
- [`RESBAK.md`](RESBAK.md): canonical design summary of the 5 characters, their skills and passives.
- [`characters/`](characters/): per-character dossiers with the numbers. **Dossiers win on numeric conflicts.**
  [01 JM (Botsog)](characters/01_jm_botsog.md) · [02 Nene](characters/02_nene.md) · [03 Batang Hamog](characters/03_batang_hamog.md) · [04 Nathan](characters/04_nathan.md) · [05 Inday](characters/05_inday.md)
- [`gameplay/agawan_base_rules.md`](gameplay/agawan_base_rules.md): arena zones, freshness engine, jail/chain/rescue, 3 win conditions.
- [`glossary.md`](glossary.md): Filipino terms → mechanics → code identifiers.

**Reality (what ships)**
- [`status.md`](status.md): implementation matrix plus known design ↔ code gaps.
- [`architecture.md`](architecture.md): scenes, player controller, state machine, input, project settings.
- [`pipelines/`](pipelines/): [blender](pipelines/blender.md) · [map_pipeline](pipelines/map_pipeline.md) · [assets](pipelines/assets.md).
- [`decisions.md`](decisions.md): dated decision log.

## Doc conventions
- Design docs say what *should* exist. Reality docs say what *does*. When code and a reality doc disagree, the code wins: fix the doc in the same change.
- Reference code as `path/to/file.gd` + a symbol name (`try_lusot`), not line numbers, because line numbers drift.
- Don't copy numbers that already live in code or dossiers. Link to them instead.
