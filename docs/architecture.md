# Runtime architecture

As shipped. If this disagrees with the code, the code wins, so fix this file.

## Entry points

| Scene | Script | Purpose |
| ----- | ------ | ------- |
| `scenes/court_playtest.tscn` (**main scene**) | `scripts/runtime/court_playtest.gd` | Full playtest: court + Batang Hamog + camera + UI. The scene is a 176-byte stub; everything is built in `_ready()`. |
| `scenes/movement_test.tscn` | `scripts/runtime/movement_test.gd` | **Older, independent** movement rig: loads the Hamog GLB directly, hardcoded WASD + Shift sprint, `base_cam_size 10.0`. It does **not** use `BatangHamogController`. |
| `scenes/barangay_court.tscn` | none | The map (≈250 KB, hand-edited / pipeline-built). See `docs/pipelines/map_pipeline.md`. |
| `scenes/court_roof.tscn` | none | Roof with `cutaway_roof.gdshader`. Not instanced anywhere right now. |

## court_playtest.gd `_ready()` build order
1. Directional "WarmAfternoonSun" light + `WorldEnvironment` (`--no-shadows` disables shadows).
2. Instance `barangay_court.tscn`, then `style_purple_tricycle`, `add_prop_contact_shadows`, and `collect_roof_materials` (a no-op while the court has no `CourtRoof`).
3. `player = BatangHamogController.new()` at `(-10, 0.2, 2)`, then toon materials on its model.
4. Orthographic camera, `size 8.5`, offset `(0, 11, 7.5)` from a smoothed focus, clamped to x ∈ [−15, 15] and z ∈ [−7.5, 13]. `illustrated_edges.gdshader` runs as a full-screen quad.
5. CanvasLayer HUD: a help label, touch D-pad (UP/DOWN/LEFT/RIGHT → `player.external_move`), **DASH** (`try_harurot`), **LUSOT** (`try_lusot`), and **MAP / FOLLOW**.

Keys handled by the playtest itself: **M** toggles map overview (camera size 31), **R** toggles the full roof (no visible effect without a roof).
CLI user args (after `--`): `--overview`, `--roof`, `--capture-preview` (saves a PNG to `user://` and quits), `--no-shadows`.

## Player: `BatangHamogController` (`scripts/runtime/batang_hamog.gd`)
`CharacterBody3D` that builds its own children in `_ready()`:

```
BatangHamogPlayer (CharacterBody3D)
├─ DireDiretso            DireDiretsoComponent (scripts/runtime/dire_diretso.gd)
├─ BodyCollision          capsule r0.35 h1.6
├─ Hurtbox3D (Area3D, layer 2) ─ capsule
├─ CharacterVisual ─ BatangHamog (GLB instance, scaled to 1.8 m)
├─ VaultDetector ─ LowObstacleCast (y0.65) / HeadClearanceCast (y1.45), both 1.2 m forward
└─ VFX: HarurotWindTrail (world-space), HarurotPushOff, LusotSlideDust, LusotMist, DireWisps
```

State machine (`enum State`): `GROUND → HARUROT → HARUROT_RECOVERY → GROUND`;
`GROUND → LUSOT_SLIDE → LUSOT_RECOVERY → GROUND`; `GROUND → LUSOT_VAULT → GROUND`.
Lusot chooses **vault** when the low cast hits and the head cast is clear; otherwise it **slides**, which halves both the body capsule and the hurtbox.

Facing: the body is **never rotated**. Only `CharacterVisual` and `VaultDetector` are yawed (`atan2(x, z)`, so yaw 0 faces +Z). Read the facing through `get_facing_dir()`, never `global_transform.basis`. The vault direction, the no-input slide direction and the no-input Harurot direction all use it.

Tuning (`@export`s, the code values): `base_speed 5.0`; Harurot `×2.2` for `1.2 s`, turn `18 rad/s`, cooldown `2.0 s`, recovery `0.35 s` (Walking clip); Lusot slide `0.7 s` + `0.25 s` tag lockout; vault `0.58 s`.

Dire-Diretso: +5% every 1.5 s of continuous motion at ≥ 95% of base speed, up to 4 stacks (+20%). It resets on stopping, on a reversal (dot < −0.5), on `attempt_tag()`, on `on_hit_by_skill()`, and while `is_carrying_flag`.

## Input
`project.godot` defines 7 InputMap actions. `BatangHamogController._ensure_input_actions()` also adds the defaults at runtime when they're missing:

| Action | Keys | Mouse / Joy |
| ------ | ---- | ----------- |
| `move_forward/back/left/right` | WASD + arrows | D-pad (joy 11–14) |
| `skill_harurot` | **Shift** | joy 5 |
| `skill_lusot` | **Ctrl**, **C** | joy 1 |
| `action_tag` | **E** | LMB, joy 0 |

There is no sprint key in the playtest (Shift is Harurot) and no mouse steering.

## Not yet in code
Teams, base touch / freshness timestamps, tagging resolution, jail/chain/rescue, win
conditions, the other 4 characters' controllers, networking. The map already has the
hooks: `BaseSites/{Yellow,Purple}_Site_{1..3}` and `JailZones/{Yellow,Purple}Jail` are `Area3D`s
with no scripts attached. See `docs/status.md`.

## Project settings worth knowing
Godot 4.7 Mono · `gl_compatibility` renderer (desktop + mobile) · Jolt Physics ·
viewport **1280×720**, stretch `canvas_items` / `expand` · editor plugin `addons/meshy-godot-plugin` enabled.
