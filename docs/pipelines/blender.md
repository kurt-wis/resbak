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

## Current clips

| Character | GLB | Clips (length) |
| --------- | --- | -------------- |
| Batang Hamog | `assets/characters/batang_hamog.glb` | Idle 3.00 s, Walking 1.04 s, Running 0.67 s, Harurot 1.00 s (24 f @ 24 fps), Lusot_Slide 0.96 s, Lusot_Vault 0.58 s; RunFast exported but not gate-checked |
| JM (Botsog), procedural, unused | `assets/characters/jm_botsog.glb` | Idle 2.00 s, Walking 1.07 s, Running 0.60 s (30 fps); 55 bones |
| Tutoy, Nene, Nathan, JM, Inday | `assets/characters/{tutoy,nene,nathan,jm,inday}.glb` | Idle 2.00 s (48 f), Walking 1.04 s (25 f), Running 0.67 s (16 f) @ 24 fps; 462–469 tracks; 66 bones (JM 67) |

## Meshy heroes (`build_heroes.py`)
Sources are the Meshy auto-rigged GLBs in `source_art/heroes/` (copies of the files dropped in the repo root; Tutoy was called Dodong until 2026-10-16). Each arrived with Mixamo names, an A-pose, facing −Y, and one clip (Running; JM: Walking), plus a stray 2 m `Icosphere` the builder deletes.
- **Retarget in armature space**: per bone, offset `D = R_pose · R_rest⁻¹` from the source, applied as `D · R_rest` on the target. Bone rolls differ between Meshy rigs, so copying local rotations would twist limbs; armature-space offsets don't care about roll. Hips translation is scaled by hip height.
- Walking ← JM's native walk for everyone; Running ← each hero's own, JM's from Tutoy. Native clips are re-baked too so every clip has the same tracks.
- **Idle** is generated: hips/legs at rest (feet planted), upper body = quaternion average of the hero's walk cycle (arms relaxed), plus a 2 s breathing/head/arm sway.
- Review stills: `renders/heroes_<id>_{idle,walking,running}.png` from the game's 3/4 top-down angle.

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
