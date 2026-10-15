# Blender character pipeline

Blender 5.2 LTS, headless, pure `bpy`. Scripts live in [`tools/`](../../tools/README.md)
and resolve paths from their own location.

```powershell
& $env:BLENDER -b --python tools/build_batang_hamog.py   # stage 1: raw source -> locomotion GLB
& $env:BLENDER -b --python tools/build_hamog_moveset.py  # stage 2: + Harurot, Lusot_Slide, Lusot_Vault
& $env:BLENDER -b --python tools/build_jm_botsog.py      # JM: procedural model + rig + clips + renders
```

Then run the integration gate (`AGENTS.md` → Commands).

## Rig and export rules (enforced by `scripts/tests/integration_test.gd`)
- **Mixamo bone names** (`mixamorig:Hips`, `mixamorig:Spine`, …) so clips retarget across characters. JM adds `mixamorig:Towel1_R` / `Towel2_R`.
- Clips are exported as **NLA tracks** (`export_animation_mode='NLA_TRACKS'`) into one `.glb`; Godot exposes them through the GLB's `AnimationPlayer`.
- Every clip must animate the full skeleton: **≥ 60 tracks** (Hamog currently 65, JM 162).
- Clip names are matched case-insensitively by `BatangHamogController._detect_clips()`: `idle`, `walking`, `running`, `runfast` (fallback for running), `harurot`, `lusot_slide`, `lusot_vault`.
- **`Slide` and `Dash` must never reappear** (exact-name asserts; `Lusot_Slide` is allowed). They were removed 2026-10-14.

## Current clips

| Character | GLB | Clips (length) |
| --------- | --- | -------------- |
| Batang Hamog | `assets/characters/batang_hamog.glb` | Idle 3.00 s, Walking 1.04 s, Running 0.67 s, Harurot 1.00 s (24 f @ 24 fps), Lusot_Slide 0.96 s, Lusot_Vault 0.58 s; RunFast exported but not gate-checked |
| JM (Botsog) | `assets/characters/jm_botsog.glb` | Idle 2.00 s, Walking 1.07 s, Running 0.60 s (30 fps); 55 bones |

## Harurot keyframe structure (Hamog)
0–4 anticipation coil → 8 push-off → 13 airborne stride → 17 landing squash → 20 held
recovery → 24 pop to the exact Idle frame-0 stance (`IDLE_F0` in `build_hamog_moveset.py`).
At runtime the recovery window plays **Walking, never Running** (gate-asserted).

## JM build phases
`build_jm_botsog.py` builds in phases and renders a front + quarter still after each
(`renders/jm_phase1_setup_*.png` … `jm_phase7_final_*.png`), plus walk/sprint side frames and
`renders/jm_build_meta.json`. JM faces −Y, height 1.40 m, ground Z = 0, XYZ Euler.

## Adding a new character (checklist)
1. Write `tools/build_<name>.py` following `build_jm_botsog.py` (repo-relative `PROJ`, renders to `renders/`, .blend to `source_art/<name>/`).
2. Export to `assets/characters/<name>.glb` with Mixamo names + NLA clips.
3. Add a GLB section to `scripts/tests/integration_test.gd` (clips, ≥60 tracks, no Slide/Dash).
4. Update `docs/status.md`, the character dossier's *Implementation status*, and the table above.
