# AGENTS.md — RESBAK

Operating manual for coding agents (and humans). Keep it short and true: it **routes**
you to the file that holds each fact rather than copying the fact here.

## What this is
**RESBAK** is a stylized 3D competitive action game based on the Filipino street game
**Agawan Base**: 5v5, anyone away from their base can be tagged and the first clean tag wins
(Unahan), each team is barred from its own base, tagged players go to the enemy jail and are
freed by touching the tip of a human chain, and a team scores by capturing the enemy base. Setting: an open-air barangay court. Entry build: LAN plus
bots, Windows only, due 25 Oct 2026.

**The design spec is [`docs/design/RESBAK_GDD.md`](docs/design/RESBAK_GDD.md)**, a condensed
(~7k words) version of the team's full GDD. Build from it. The full GDD (a long PDF for people)
is kept outside the repo; don't ask for it unless the spec is unclear.

- **Engine:** Godot 4.7 Mono · GL Compatibility · Jolt Physics · 1280×720, `canvas_items`/`expand`
- **Language:** GDScript (no C# yet, despite the Mono build)
- **Assets:** Blender 5.2 headless `bpy` scripts in `tools/`
- **State today:** a character select (main scene) with five heroes (Tutoy, Nene, Nathan,
  JM, Inday) that break dance on the select screen and idle/walk/run around the court. Batang
  Hamog's skills prototype is only reachable with `--hero=hamog`. Core
  Agawan Base rules are **not implemented yet**. See [`docs/status.md`](docs/status.md).

## Where to look

| Task | Go to |
| ---- | ----- |
| What's built vs. designed | [`docs/status.md`](docs/status.md) |
| How the runtime fits together (scenes, controller, input) | [`docs/architecture.md`](docs/architecture.md) |
| Game rules (Unahan tagging, base barrier, jail, chain, rescue, round end) | spec § 2 Core rules |
| Every tuning number | spec § 3 Numbers at a glance (the code's tuning values must match it) |
| A character's skills and numbers | spec § 4 Characters |
| Maps, match flow, HUD, modes, controls, settings, bots | spec § 5 to § 11 |
| Networking, tick order, save data, structure, build order | spec § 12 Technical |
| On-screen text and announcer lines | spec § 13 Strings |
| Is a feature in the 25 Oct entry, the finals or later? | spec § 1, What ships when (that table wins) |
| Filipino terms | [`docs/glossary.md`](docs/glossary.md) |
| Hero roster, locomotion, character select | `scripts/runtime/hero_roster.gd`, `hero_controller.gd`, `character_select.gd` |
| Skills prototype code (Batang Hamog) | `scripts/runtime/batang_hamog.gd`, `scripts/runtime/dire_diretso.gd` |
| Playtest world, camera, HUD | `scripts/runtime/court_playtest.gd` (main scene `scenes/court_playtest.tscn`) |
| The map | `scenes/barangay_court.tscn`. Edit it directly; see [`docs/pipelines/map_pipeline.md`](docs/pipelines/map_pipeline.md) |
| Character models and animation | `tools/` + [`docs/pipelines/blender.md`](docs/pipelines/blender.md) |
| Props, textures, LFS | [`docs/pipelines/assets.md`](docs/pipelines/assets.md) |
| Why something is the way it is | [`docs/decisions.md`](docs/decisions.md) |
| Full docs index | [`docs/README.md`](docs/README.md) |

## Layout
```
scenes/               character_select (main), court_playtest, movement_test (old rig), barangay_court (map), court_roof
scripts/runtime/      game code: HeroController, HeroRoster, BatangHamogController, DireDiretsoComponent, playtest/select
scripts/tests/        integration_test.gd = THE GATE; legacy/ = stale snapshot checks (not run)
scripts/map_pipeline/ ⚠ one-shot builders that OVERWRITE scenes/assets. Never run them to inspect.
shaders/              all spatial shaders (toon, outline, painted surfaces, roof cutaway, jail)
assets/               game-ready: characters/*.glb, props/*.tscn, environment textures
imported_models/      raw prop packs → assets/props via map_pipeline/prepare_props.gd
source_art/           raw character sources + .blend (Godot-ignored); heroes/ = Meshy hero GLBs
tools/                Blender builders (see tools/README.md)
renders/              Blender review stills (Godot-ignored)
addons/               meshy-godot-plugin (third-party; don't edit)
docs/                 design/ = the spec · reality docs · archive/ = superseded design docs (index: docs/README.md)
```

## Commands
`godot` and `blender` are **not on PATH**. Set these env vars once per shell. The paths below are this machine's; adjust them for others:

```powershell
$env:GODOT   = "C:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
$env:BLENDER = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
```

| Purpose | Command (run from repo root) |
| ------- | ---------------------------- |
| **Gate (required)** | `& $env:GODOT --headless --path . -s scripts/tests/integration_test.gd` |
| Refresh import / uid cache (after moving files) | `& $env:GODOT --headless --path . --import` |
| Play (character select) | `& $env:GODOT --path .` |
| Playtest one hero | `& $env:GODOT --path . res://scenes/court_playtest.tscn -- --hero=nene` (ids: tutoy nene nathan jm inday, dev-only hamog; more user args: `--overview --roof --capture-preview --no-shadows`) |
| Rebuild Batang Hamog | `& $env:BLENDER -b --python tools/build_batang_hamog.py`, then `tools/build_hamog_moveset.py` (order matters) |
| Rebuild the five heroes | `& $env:BLENDER -b --python tools/build_heroes.py` (one: `... -- nene`) |
| Rebuild procedural JM (unused) | `& $env:BLENDER -b --python tools/build_jm_botsog.py` |

**Gate pass** means exit code 0, the last line reads `All checks passed successfully (100%)!`, and there are no `SCRIPT ERROR` lines. A failed assert can **hang** the gate instead of exiting, so if it runs longer than about a minute, treat it as failed.

## Hard rules
1. **Run the gate before calling anything done**, and report the result. If you add a feature, add asserts for it to `integration_test.gd`.
2. **Never run `scripts/map_pipeline/*.gd`** unless the task is explicitly to re-run that step. They rewrite `barangay_court.tscn` and other assets in place.
3. **Never reintroduce `Slide` or `Dash` animation clips** (the gate asserts they're absent). Harurot recovery must play **Walking, never Running**.
4. Character rigs use **Mixamo bone names** (`mixamorig:*`), export clips as **NLA tracks**, and have **≥ 60 tracks per clip**.
5. **Move or rename a `.gd` together with its `.gd.uid`**, and an asset together with its `.import`. Then grep for `res://` references to update and run `--import`.
6. Use `res://` paths in GDScript and repo-relative paths in `tools/*.py`. Never use absolute machine paths.
7. Don't edit `addons/` or `.godot/`. Don't commit `.opencode/` or `__pycache__/`.
8. Large binaries (`*.glb *.png *.jpg *.blend *.res *.pdf *.fbx`) go through **Git LFS** (`.gitattributes`).

## Source of truth
- **Design intent:** `docs/design/RESBAK_GDD.md`, and nothing else. `docs/archive/` is history only; never implement from it.
- **Scope:** the spec's "What ships when" table. Build entry features first; don't build finals or later features unless asked.
- **Don't edit `docs/design/`.** It is exported from the team's full GDD. If the spec is wrong, unclear or missing something, say so and log the gap in `docs/status.md`.
- **Shipped behavior:** the code. **If code and docs disagree, the code wins.** Fix the doc in the same change, and note any design ↔ code gap in `docs/status.md`.

## Keeping docs true (do this in the same change)
| You changed… | Also update |
| ------------ | ----------- |
| A skill, passive, or game system | `docs/status.md`, and `docs/architecture.md` if structure or input changed. Use the spec's numbers; if you must deviate, log it in `docs/status.md` |
| An animation clip or rig | `docs/pipelines/blender.md` (clip table), plus the gate asserts |
| Folder layout, commands, or a hard rule | this file |
| A non-obvious choice | `docs/decisions.md` (dated entry) |
| A new Filipino-named mechanic | `docs/glossary.md` |
