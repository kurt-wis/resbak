# Blender character pipeline

Blender 5.2 LTS, headless, pure `bpy`. Scripts live in [`tools/`](../../tools/README.md)
and resolve paths from their own location.

```powershell
& $env:BLENDER -b --python tools/build_batang_hamog.py   # stage 1: raw source -> locomotion GLB
& $env:BLENDER -b --python tools/build_hamog_moveset.py  # stage 2: + Harurot, Lusot_Slide, Lusot_Vault
& $env:BLENDER -b --python tools/build_jm_botsog.py      # JM: procedural model + rig + clips + renders
& $env:BLENDER -b --python tools/build_heroes.py         # Tutoy, Nene, Nathan, JM, Inday (Meshy rigs)
& $env:BLENDER -b --python tools/build_heroes.py -- nene # just one hero
```

Then run the integration gate (`AGENTS.md` → Commands).

## Rig and export rules (enforced by `scripts/tests/integration_test.gd`)
- **Mixamo bone names** (`mixamorig:Hips`, `mixamorig:Spine`, …) so clips retarget across characters. JM adds `mixamorig:Towel1_R` / `Towel2_R`.
- Clips are exported as **NLA tracks** (`export_animation_mode='NLA_TRACKS'`) into one `.glb`; Godot exposes them through the GLB's `AnimationPlayer`.
- Every clip must animate the full skeleton: **≥ 60 tracks** (Hamog currently 65, JM 162).
- Clip names are matched case-insensitively by `BatangHamogController._detect_clips()`: `idle`, `walking`, `running`, `runfast` (fallback for running), `harurot`, `lusot_slide`, `lusot_vault`.
- **`Slide` and `Dash` must never reappear** (exact-name asserts; `Lusot_Slide` is allowed). They were removed 2026-10-14.

## Definition of done for any model or animation change
Scripts report success even when a mesh floats or a cycle skates, so check before calling it done:
1. `& $env:BLENDER -b --python tools/qc_asset.py -- <glb> --speed Walking=<walk m/s> --speed Running=<run m/s>`: no FAIL lines.
2. Open `renders/qc/<name>_sheet.png` (front, side / top, 3/4) and look at it: floating parts, wrong facing, intersections.
3. If a clip's foot-plant speed changed, update `walk_clip_speed` / `run_clip_speed` in `hero_roster.gd`.
- Facing: heroes face -Y in Blender, which exports to +Z (`Vector3.MODEL_FRONT`) in Godot. Floor props have their origin at the bottom centre; held or thrown props (Kimkim) at their middle (`--held`).
- Prefer bmesh and `bpy.data` edits in builders; `bpy.ops` mesh edits depend on selection and break headless.
- IK and look-at in Godot 4.7: use `SkeletonModifier3D` nodes (e.g. `LookAtModifier3D`), not the deprecated `SkeletonIK3D`.

## Current clips

| Character | GLB | Clips (length) |
| --------- | --- | -------------- |
| Batang Hamog | `assets/characters/batang_hamog.glb` | Idle 3.00 s, Walking 1.04 s, Running 0.67 s, Harurot 1.00 s (24 f @ 24 fps), Lusot_Slide 0.96 s, Lusot_Vault 0.58 s; RunFast exported but not gate-checked |
| JM (Botsog), procedural, unused | `assets/characters/jm_botsog.glb` | Idle 2.00 s, Walking 1.07 s, Running 0.60 s (30 fps); 55 bones |
| Tutoy, Nene, Nathan, JM, Inday | `assets/characters/{tutoy,nene,nathan,jm,inday}.glb` | Idle 2.50 s, Walking 1.04 s, Running 0.92 s, BreakDance per hero (Tutoy 3.0 s, Nene 3.9 s, Nathan 3.2 s, JM 6.7 s, Inday 4.9 s) @ 24 fps; 660 tracks (JM 670); 66 bones (JM 67) |

## Meshy heroes (`build_heroes.py`)
Sources are the Meshy auto-rigged GLBs in `source_art/heroes/` (Tutoy was called Dodong until 2026-10-16): Mixamo names, A-pose, facing −Y, plus a stray 2 m `Icosphere` the builder deletes. Clips come from mocap through `tools/retarget_clip.py`:
- **Retarget**: per bone, the source's world motion offset `D = R_pose · R_rest⁻¹`, applied after swinging the target bone onto the source's rest direction. That ignores bone roll and fixes T-pose sources (Mixamo, Quaternius) on our A-pose heroes. Resampled to 24 fps; hips height scaled to the hero.
- **Idle** = Quaternius `Idle_Loop`, **Running** = Quaternius `Jog_Fwd_Loop` (`mixamo/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb`, CC0). **Walking** = the walk Meshy shipped with JM, for everyone: Quaternius `Walk_Loop` is a stroll (feet ~0.8 m/s) that would play ~3× at the design's 2.5 m/s walk. A file `source_art/mocap/<id>_walk.*` / `<id>_run.*` overrides per hero.
- Locomotion clips are shifted so their lowest sole touches the floor (`bake_grounded`).
- **BreakDance** (character select only) = each hero's own Mixamo routine (`BREAKDANCE` in the builder, files in the repo-root `mixamo/breakdance-pack/`): Tutoy footwork 2 → 2× flair, Nene 2× uprock var 1, Nathan footwork 1, JM freezes, Inday Brooklyn uprock. Each move's travel, height change and spin are removed, moves cross-fade over 8 frames, floor travel is shrunk to a 0.35 m radius so the dancer stays on the pad, the end eases into frame 0 (seamless loop), and any frame where the mesh dips under the floor is lifted (smoothed). Uprock footsteps slide a little as a result.
- After rebuilding, run `tools/qc_asset.py` and copy the Walking / Running foot-plant speeds into `hero_roster.gd`.
- Review stills: `renders/heroes_<id>_{idle,walking,running}.png` from the game's 3/4 top-down angle, and `renders/heroes_breakdance.png` (rows = heroes, six dance frames each).

## Harurot keyframe structure (Hamog)
0–4 anticipation coil → 8 push-off → 13 airborne stride → 17 landing squash → 20 held
recovery → 24 pop to the exact Idle frame-0 stance (`IDLE_F0` in `build_hamog_moveset.py`).
At runtime the recovery window plays **Walking, never Running** (gate-asserted).

## JM build phases
`build_jm_botsog.py` builds in phases and renders a front + quarter still after each
(`renders/jm_phase1_setup_*.png` … `jm_phase7_final_*.png`), plus walk/sprint side frames and
`renders/jm_build_meta.json`. JM faces −Y, height 1.40 m, ground Z = 0, XYZ Euler.

## Adding a new character (checklist)
0. Meshy auto-rigged model with Mixamo names? Drop it in `source_art/heroes/`, add it to `HEROES` in `tools/build_heroes.py` and `scripts/runtime/hero_roster.gd`, and skip to step 3.
1. Write `tools/build_<name>.py` following `build_jm_botsog.py` (repo-relative `PROJ`, renders to `renders/`, .blend to `source_art/<name>/`).
2. Export to `assets/characters/<name>.glb` with Mixamo names + NLA clips.
3. Add a GLB section to `scripts/tests/integration_test.gd` (clips, ≥60 tracks, no Slide/Dash).
4. Update `docs/status.md`, the character dossier's *Implementation status*, and the table above.
