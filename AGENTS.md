# AGENTS.md — RESBAK

Operating manual for coding agents (and humans). Keep it short and true: it **routes**
you to the file that holds each fact rather than copying the fact here.

## What this is
**RESBAK** is a stylized 3D competitive action game based on the Filipino street game
**Agawan Base**: 5v5, anyone away from their base can be tagged and the first clean tag wins
(Unahan), each team is barred from its own base, tagged players go to the enemy jail and are
freed by touching the tip of a human chain, and a team scores by capturing the enemy base.
Setting: an open-air barangay court. Entry build: LAN plus bots, Windows desktop only (no mobile or touch), due 25 Oct 2026.

**The design spec is [`docs/RESBAK.md`](docs/RESBAK.md)**, the single source of truth (a
condensed spec of the team's full GDD, which is a long PDF kept outside the repo).

- **Engine:** Godot 4.7 Mono · GL Compatibility · Jolt Physics · **1920×1080** base, `canvas_items`/`expand`, borderless fullscreen · 60 physics ticks/s
- **Language:** GDScript (no C# yet, despite the Mono build)
- **Assets:** Blender 5.2 headless `bpy` scripts in `tools/`; hero clips from Meshy (rig + animation library) retargeted there
- **State today:** the full offline loop runs: boot → title → first-time setup → Home → Play
  (vs Bots) → map/base roulette → snake draft → match (core rules, all five heroes' skills and
  passives, bots, HUD) → results. LAN, maps other than Barangay Court, hazards, tutorial and audio
  assets are not built yet. See [`docs/status.md`](docs/status.md).

## Where to look

| Task | Go to |
| ---- | ----- |
| What's built vs. designed, known gaps | [`docs/status.md`](docs/status.md) |
| How the runtime fits together (tick order, systems, skills API, scenes, input) | [`docs/architecture.md`](docs/architecture.md) |
| Game rules (Unahan tagging, base barrier, jail, chain, rescue, round end) | spec § 2 → `scripts/match/systems/` |
| Every tuning number | spec § 3 → `data/tuning.tres` (shared) and `data/heroes/<id>.tres` (per hero). Never hard-code numbers. |
| A character's skills | spec § 4 → `scripts/match/skills/<hero>/` |
| Bots | spec § 11 → `scripts/match/bots/` |
| HUD | spec § 7 → `scripts/ui/hud/` |
| Front end (menus, draft, results, settings) | spec § 6, § 8, § 10 → `scripts/ui/frontend/`, `scenes/frontend/` |
| Save data, Session, Audio, bindings | spec § 12 → `scripts/autoload/` |
| Is a feature in the 25 Oct entry, the finals or later? | spec § 1, What ships when (that table wins) |
| Filipino terms | [`docs/glossary.md`](docs/glossary.md) |
| The map | `scenes/barangay_court.tscn`. Edit it directly; see [`docs/pipelines/map_pipeline.md`](docs/pipelines/map_pipeline.md) |
| Character models and animation clips | `tools/` + [`docs/pipelines/blender.md`](docs/pipelines/blender.md) |
| Props, textures, LFS | [`docs/pipelines/assets.md`](docs/pipelines/assets.md) |
| Why something is the way it is | [`docs/decisions.md`](docs/decisions.md) |
| Full docs index | [`docs/README.md`](docs/README.md) |

## Layout
```
scenes/               frontend/*.tscn (boot = main scene), match.tscn, barangay_court (map), court_roof,
                      character_select / court_playtest / movement_test (legacy dev scenes)
scripts/match/        the match: MatchHost (tick order), Hero, HeroVisual, systems/ (tag, base, jail, round),
                      skills/<hero>/ (one script per skill and passive + their SkillObjects), bots/, MatchView, camera
scripts/ui/           hud/ (match HUD parts), frontend/ (screens, draft, results, settings; Home = home.gd + home_diorama*.gd live 3D backdrop, hero_picker.gd, home_skin.gd)
scripts/autoload/     Save, Session, Audio (autoloads) + Controls (default bindings)
scripts/runtime/      legacy dev code: HeroController, HeroRoster, character select, Batang Hamog prototype
scripts/tests/        integration_test.gd = THE GATE (runs suites/*.gd); legacy/ = stale snapshot checks (not run)
scripts/map_pipeline/ ⚠ one-shot builders that OVERWRITE scenes/assets. Never run them to inspect.
data/                 tuning.tres, heroes/<id>.tres (HeroData), home_diorama.tres (Home diorama numbers)
shaders/              all spatial shaders (toon, toon fade, outline, painted surfaces, roof cutaway, jail, Home diorama set / sky / depth blur, face flipbook)
assets/               game-ready: characters/*.glb (+ bystanders/, face_cards/), props/*.tscn (+ home/), audio/, fonts/, ui/home/, environment textures
source_art/           raw sources (Godot-ignored): heroes/ (Meshy GLBs), mocap/meshy/ + mocap/quaternius/
mixamo/               Mixamo breakdance pack (Godot-ignored)
tools/                Blender builders (see tools/README.md)
renders/              Blender review stills and QC sheets (Godot-ignored)
addons/               meshy-godot-plugin (third-party; don't edit)
docs/                 RESBAK.md = the spec · reality docs · archive/ = superseded design docs
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
| One or more suites | `... integration_test.gd -- --only=core_rules,kit_jm` (names in `scripts/tests/README.md`) |
| Refresh import / class cache (after adding `class_name` scripts or moving files) | `& $env:GODOT --headless --path . --import` |
| Play (front end) | `& $env:GODOT --path .` (add `--windowed --resolution 1600x900` for a window) |
| Straight into a match | `& $env:GODOT --path . res://scenes/match.tscn -- --hero=nene` (also `--difficulty=0..2 --seed=N --tradisyonal --autoplay --no-shadows`) |
| Rebuild the Konstruksyon vehicles | `& $env:BLENDER -b --python tools/build_vehicle_props.py` (one: `... -- digger`), then `tools/qc_asset.py` |
| Rebuild the five heroes | `& $env:BLENDER -b --python tools/build_heroes.py` (one: `... -- nene`), then `tools/qc_asset.py` |
| Rebuild Batang Hamog (legacy) | `& $env:BLENDER -b --python tools/build_batang_hamog.py`, then `tools/build_hamog_moveset.py` |

**Gate pass** means exit code 0, the last line reads `All checks passed successfully (100%)!`, and no `SCRIPT ERROR` lines. Failures are counted and reported (the gate no longer hangs on a failed check), but a script crash can still stall it: stop it after about five minutes.

## Hard rules
1. **Run the gate before calling anything done**, and report the result. If you add a feature, add checks for it to a suite in `scripts/tests/suites/`.
2. **Never run `scripts/map_pipeline/*.gd`** unless the task is explicitly to re-run that step.
3. **Never name an animation clip exactly `Slide` or `Dash`** (gate-checked). Harurot recovery on the legacy Hamog rig plays Walking, never Running.
4. Character rigs use **Mixamo bone names** (`mixamorig:*`), export clips as **NLA tracks**, and every clip animates the full skeleton (≥ 60 tracks). Clip names are a contract with the game code: see `docs/pipelines/blender.md`.
5. **Gameplay runs on the host tick** (`MatchHost.step`, spec § 12 tick order). It never reads `Input` directly; players and bots both produce `InputFrame`s. Numbers come from `data/`, never literals.
6. **Move or rename a `.gd` together with its `.gd.uid`**, and an asset together with its `.import`. Then grep for `res://` references and run `--import`.
7. Use `res://` paths in GDScript and repo-relative paths in `tools/*.py`. Never use absolute machine paths.
8. Don't edit `addons/` or `.godot/`. Don't commit `.opencode/`, `__pycache__/`, `gate_*.txt` or a stray `dev/` folder.
9. Large binaries (`*.glb *.png *.jpg *.blend *.res *.pdf *.fbx`) go through **Git LFS** (`.gitattributes`).

## Source of truth
- **Design intent:** `docs/RESBAK.md`, and nothing else. `docs/archive/` is history only.
- **Scope:** the spec's "What ships when" table. Build entry features first.
- **Don't edit `docs/RESBAK.md`.** If it is wrong, unclear or missing something, say so and log the gap in `docs/status.md`. If code and the spec disagree, ask; don't guess.
- **Shipped behaviour:** the code. Reality docs (`status`, `architecture`, pipelines) follow the code; fix them in the same change.

## Keeping docs true (do this in the same change)
| You changed… | Also update |
| ------------ | ----------- |
| A skill, passive, or game system | `docs/status.md`, and `docs/architecture.md` if structure or input changed. Deviations from spec numbers go in `docs/status.md` |
| An animation clip or rig | `docs/pipelines/blender.md` (clip table), plus the `hero_assets` suite |
| Folder layout, commands, or a hard rule | this file |
| A non-obvious choice | `docs/decisions.md` (dated entry) |
| A new Filipino-named mechanic | `docs/glossary.md` |
