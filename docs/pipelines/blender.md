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
- Every clip must animate the full skeleton: **≥ 60 tracks** (Hamog currently 65, JM 162; the five heroes 63 in Godot, which drops tracks whose value never changes: 660 channels in Blender, JM 670).
- Clip names are matched case-insensitively by `BatangHamogController._detect_clips()`: `idle`, `walking`, `running`, `runfast` (fallback for running), `harurot`, `lusot_slide`, `lusot_vault`.
- The five heroes' clip names (tables below) are the game's contract: `scripts/match/hero_visual.gd` looks them up by exact name and loops the ones in its `LOOP_CLIPS`.
- **`Slide` and `Dash` must never reappear** (exact-name asserts; `Lusot_Slide` is allowed). They were removed 2026-10-14.

## Definition of done for any model or animation change
Scripts report success even when a mesh floats or a cycle skates, so check before calling it done:
1. `& $env:BLENDER -b --python tools/qc_asset.py -- <glb> --speed Walking=<walk m/s> --speed Running=<run m/s>`: no FAIL lines.
2. Open `renders/qc/<name>_sheet.png` (front, side / top, 3/4) and look at it: floating parts, wrong facing, intersections.
3. If a clip's foot-plant speed changed, update `walk_clip_speed` / `run_clip_speed` in `data/heroes/<id>.tres` (HeroData), where the game reads them. The `FAIL foot slide` lines for Walking / Running are expected until then: they give the playback scale the game applies.
- Facing: heroes face -Y in Blender, which exports to +Z (`Vector3.MODEL_FRONT`) in Godot. Floor props have their origin at the bottom centre; held or thrown props (Kimkim) at their middle (`--held`).
- Prefer bmesh and `bpy.data` edits in builders; `bpy.ops` mesh edits depend on selection and break headless.
- IK and look-at in Godot 4.7: use `SkeletonModifier3D` nodes (e.g. `LookAtModifier3D`), not the deprecated `SkeletonIK3D`.

## Current clips

| Character | GLB | Clips (length) |
| --------- | --- | -------------- |
| Batang Hamog | `assets/characters/batang_hamog.glb` | Idle 3.00 s, Walking 1.04 s, Running 0.67 s, Harurot 1.00 s (24 f @ 24 fps), Lusot_Slide 0.96 s, Lusot_Vault 0.58 s; RunFast exported but not gate-checked |
| JM (Botsog), procedural, unused | `assets/characters/jm_botsog.glb` | Idle 2.00 s, Walking 1.07 s, Running 0.60 s (30 fps); 55 bones |
| Tutoy, Nene, Nathan, JM, Inday | `assets/characters/{tutoy,nene,nathan,jm,inday}.glb` | Per-hero tables below; 24 fps; 63 tracks per clip in Godot (660 channels, JM 670); 66 bones (JM 67) |

## Meshy heroes (`build_heroes.py`)
Sources are the Meshy auto-rigged GLBs in `source_art/heroes/` (Tutoy was called Dodong until 2026-10-16): Mixamo names, A-pose, facing −Y, plus a stray 2 m `Icosphere` the builder deletes. Every clip is retargeted through `tools/retarget_clip.py` and listed in one clip table per hero (`HERO_CLIPS`) plus the shared core-rule clips (`SHARED`) in the builder.

**Meshy step (AI-assisted art: log it on Form 03).** Each hero was auto-rigged by Meshy from its source GLB, and Meshy preset animations were applied per hero; two clips are Meshy text-to-motion: Nathan's Buga and the shared Tag. All were generated in the team's Meshy account on 2026-10-16 (147 credits). Files: `source_art/mocap/meshy/` (contents in `source_art/README.md`). These clips come on Meshy's own 24-bone rig, which `retarget_clip.py` maps by name. Its spine runs Hips → `Spine02` → `Spine01` → `Spine` → `neck`, so `Spine02` is the *lowest* spine bone and maps to `mixamorig:Spine`.

- **Retarget**: per bone, the source's world motion offset `D = R_pose · R_rest⁻¹`, applied after swinging the target bone onto the source's rest direction. That ignores bone roll and fixes T-pose sources (Mixamo, Quaternius) on our A-pose heroes. Resampled to 24 fps; hips height scaled to the hero.
- **Clip entry options** (`clip(...)` in the builder): `trim` / `warp` (seconds in the source; Meshy frame / 24); `loop` (travel and spin removed so the seam is exact, open loops closed, and every loop eases its last 3 frames into frame 0 unless `blend` sets another count); `in_place` (one-shots: travel along the move removed, since the game moves the body); `face` / `turn` (turn a clip that stands turned); `plant`.
- **Grounding**: a clip is shifted so its lowest point touches the floor over the whole clip (jumps keep their air time). `plant=True` grounds every frame on its lowest sole instead. Retargeted hips heights drift against each hero's leg length, so standing clips hovered up to 7 cm (JM's Proud_Strut, Capture, Victory, Buga, Ubo). In Talbog_Slam JM's hand reaches 11 cm below his soles, which floated the whole clip 11–20 cm.
- **Chained** is authored from the hero's own Idle: the pose is turned to face front, then both arms are held out to the sides about horizontal (a little forward and down), with the forearms continuing the line, as if holding hands in the chain.
- **BreakDance** (character select only) = each hero's own Mixamo routine (`BREAKDANCE` in the builder, files in the repo-root `mixamo/breakdance-pack/`): Tutoy footwork 2 → 2× flair, Nene 2× uprock var 1, Nathan footwork 1, JM freezes, Inday Brooklyn uprock. Each move's travel, height change and spin are removed, moves cross-fade over 8 frames, floor travel is shrunk to a 0.35 m radius so the dancer stays on the pad, the end eases into frame 0 (seamless loop), and any frame where the mesh dips under the floor is lifted (smoothed). Uprock footsteps slide a little as a result.
- After rebuilding, run `tools/qc_asset.py` (Walking at half the hero's run speed) and copy the Walking / Running foot-plant speeds into `data/heroes/<id>.tres`.
- Review stills: `renders/heroes_<id>_{idle,walking,running}.png` from the game's 3/4 top-down angle, `renders/heroes_<id>_moves.png` (six frames of every clip, from the front-right, with floor shadows) and `renders/heroes_breakdance.png` (rows = heroes, six dance frames each).

### Shared core-rule clips (every hero)
| Clip | Source (`source_art/mocap/`) | Length | Loop |
| ---- | ---------------------------- | ------ | ---- |
| Tag | `meshy/shared_tag.glb` (text-to-motion), frames 11–27, in place. Wind-up, lunge, back: the body turns ~65° but the tagging hand reaches straight ahead | 0.667 s | no |
| TagCharge | `meshy/shared_tag_charge.glb` (text-to-motion, SMPL-H rig), whole clip, in place. Wide braced stance, slapping arm drawn back (see "TagCharge" below) | 1.958 s | yes |
| Tagged | `meshy/tutoy_moves.glb` Slap_Reaction, 18–40 | 0.917 s | no |
| Stumble | `meshy/tutoy_moves.glb` Stumble_Walk, 18–36, in place (failed tag) | 0.750 s | no |
| Stunned | `meshy/tutoy_moves.glb` Head_Hold_in_Pain, 51.2–76.8 | 1.083 s | yes |
| Jailed | `meshy/tutoy_moves.glb` Wave_for_Help, whole clip | 5.042 s | yes |
| Chained | the hero's own Idle with the arms out to the sides (authored) | = Idle | yes |
| Capture | `quaternius/UAL1_Standard.glb` Push_Loop (CC0), planted | 2.667 s | yes |
| Victory | `meshy/nene_moves.glb` Victory_Cheer, 0–33, planted | 1.375 s | yes (seamless, but not in `LOOP_CLIPS` yet) |

### TagCharge
The held hampas wind-up: `HeroVisual._desired()` plays `TagCharge` (in `LOOP_CLIPS`) while `Hero.is_charging()`; a hero without the clip keeps the normal pose. `build_heroes.py` bakes it into every hero from `source_art/mocap/meshy/shared_tag_charge.glb` (loop, in place, blend 6), then `tools/qc_asset.py -- assets/characters/<id>.glb --clip TagCharge` per hero. Source: one Meshy Prime `meshy_text_to_motion` task (10 credits, 2026-10-17), prompt "a kid leaning back in a stable wide stance, right arm drawn far back at shoulder height with an open palm, left arm forward for balance, tense and ready to slap, subtle breathing loop", 2 s.

**SMPL-H source rig.** Meshy text-to-motion (Prime) now returns FBX on an SMPL-H 52-bone rig (`Pelvis`, `L_Hip`, `Spine1..3`, `L_Collar`, ...) instead of Meshy's 24-bone rig; convert it to GLB in Blender (keep the mesh: `_import` measures the floor from it). `retarget_clip.py` maps it with `SMPL_TO_MIXAMO` (`is_smpl_rig()`). Every SMPL-H bone rests with +Y pointing up whatever its real direction, so for these rigs the swing step measures each bone's rest direction head → head of the bone matching the target's own child (leaves continue their parent). Without that the legs folded up into the body and grounding dropped the clip about 1.3 m, while every QC metric still passed: **look at the sheet**. The whole-clip grounding still logs about −0.8 to −1.1 m for this clip (SMPL-H keeps the pelvis at its standing height above an origin-level rest); that offset is constant and the grounded result is correct.

### Sand castle (Konstruksyon base prop)
`tools/build_sand_castle.py` (`& $env:BLENDER -b --python tools/build_sand_castle.py`) builds `assets/props/sand_castle.glb` + `.tscn`: `SandCastle` (mound, keep, four turrets, tall tower, pole; 534 tris) and a separate white `Flag` that `ArenaArt` tints per team and waves. Origin at the base, about 2.3 m tall. No rig, no clips. QC: `& $env:BLENDER -b --python tools/qc_asset.py -- assets/props/sand_castle.glb --height 0 --max-tris 3000` writes `renders/qc/sand_castle_sheet.png`.

### Per-hero clips
Meshy presets from `source_art/mocap/meshy/<id>_moves.glb` unless noted; frame numbers at 24 fps.

| Hero | Clip | Source | Length | Loop |
| ---- | ---- | ------ | ------ | ---- |
| Tutoy | Idle | Idle_5, turned to face front (it stands ~42° turned) | 1.792 s | yes |
| | Walking | Quick_Walk, first 1 s cycle | 1.000 s | yes |
| | Running | Lean_Forward_Sprint | 0.583 s | yes |
| | BreakDance | Mixamo footwork 2 → 2× flair | 3.000 s | yes |
| | Harurot | run_fast_2 | 0.583 s | yes |
| | Lusot_Slide | slide_light, 5–25, in place | 0.833 s | no |
| | Lusot_Vault | Unarmed_Vault, in place | 0.833 s | no |
| Nene | Idle | Happy_Sway_Standing | 10.000 s | yes |
| | Walking | Skip_Forward | 2.875 s | yes |
| | Running | run_fast_7 | 0.917 s | yes |
| | BreakDance | Mixamo 2× uprock var 1 | 3.875 s | yes |
| | Iyak | Angry_To_Tantrum_Sit, 66–114: sitting tantrum, crying and kicking | 2.000 s | yes |
| | Sumbong | Call_Gesture, 45–72: arm sweeps up, then calls with a hand at the mouth | 1.125 s | no |
| Nathan | Idle | Scheming_Hand_Rub | 3.292 s | yes |
| | Walking | Sneaky_Walk (sideways creep, body ~50° to his right) | 2.833 s | yes |
| | Running | run_fast_9 | 0.625 s | yes |
| | BreakDance | Mixamo footwork 1 | 3.167 s | yes |
| | Buga | `meshy/nathan_buga.glb` (text-to-motion), time-warped so the blow peaks at 0.4 s, planted | 1.208 s | no |
| | Ubo | Over_Shoulder_Throw, 54–74: hand up by the shoulder, then the throw forward and down, planted | 0.833 s | no |
| JM | Idle | Idle_11 | 1.833 s | yes |
| | Walking | Proud_Strut, planted | 4.500 s | yes |
| | Running | run_fast_4 | 0.667 s | yes |
| | BreakDance | Mixamo freezes | 6.708 s | yes |
| | Talbog_Jump | Regular_Jump, 4–26 (crouch, airborne, just before landing), turned 40° to face front | 0.917 s | no |
| | Talbog_Slam | Charged_Ground_Slam, 33–66 (impact and recovery), planted | 1.375 s | no |
| | Tamaraw | Male_Head_Down_Charge, in place | 0.542 s | yes |
| | GuardBreak | Hit_Reaction_to_Waist, 3–27, turned to face front | 1.000 s | no |
| Inday | Idle | Hand_on_Hip_Gesture | 5.000 s | yes |
| | Walking | Confident_Strut | 2.667 s | yes |
| | Running | run_fast_6 | 0.833 s | yes |
| | BreakDance | Mixamo Brooklyn uprock | 4.875 s | yes |
| | Ihip | mage_soell_cast_3, 32.8–60.8: held two-arms-forward push | 1.167 s | yes |
| | Sagip | Cheer_with_Both_Hands_Up, 3–36 | 1.375 s | no |

Planted-foot speeds from `qc_asset.py` (game m/s, 2026-10-16), for `data/heroes/<id>.tres`:

| Hero | Walking clip (walk speed, playback) | Running clip (run speed, playback) |
| ---- | ----------------------------------- | ---------------------------------- |
| Tutoy | 1.42 (2.7, ×1.90) | 4.28 (5.4, ×1.26) |
| Nene | 1.21 (2.5, ×2.07) | 3.06 (5.0, ×1.63) |
| Nathan | 0.28 (2.5, ×8.9) | 2.99 (5.0, ×1.67) |
| JM | 0.52 (2.3, ×4.4) | 3.72 (4.6, ×1.24) |
| Inday | 1.02 (2.5, ×2.45) | 2.26 (5.0, ×2.21) |

Known issues: Nathan's Sneaky_Walk and JM's Proud_Strut are slow character walks, so at the gamepad walk speed they play at ×8.9 and ×4.4 (keyboard players also pass through them while speeding up). In Talbog_Slam JM's fist dips up to 12 cm into the floor at impact (frames 10–24); the impact VFX should cover it.

## Harurot keyframe structure (Hamog)
0–4 anticipation coil → 8 push-off → 13 airborne stride → 17 landing squash → 20 held
recovery → 24 pop to the exact Idle frame-0 stance (`IDLE_F0` in `build_hamog_moveset.py`).
At runtime the recovery window plays **Walking, never Running** (gate-asserted).

## JM build phases
`build_jm_botsog.py` builds in phases and renders a front + quarter still after each
(`renders/jm_phase1_setup_*.png` … `jm_phase7_final_*.png`), plus walk/sprint side frames and
`renders/jm_build_meta.json`. JM faces −Y, height 1.40 m, ground Z = 0, XYZ Euler.

## Adding a new character (checklist)
0. Meshy auto-rigged model with Mixamo names? Drop it in `source_art/heroes/`, add it to `HEROES` and `HERO_CLIPS` in `tools/build_heroes.py` and give it a `data/heroes/<id>.tres`, then skip to step 3.
1. Write `tools/build_<name>.py` following `build_jm_botsog.py` (repo-relative `PROJ`, renders to `renders/`, .blend to `source_art/<name>/`).
2. Export to `assets/characters/<name>.glb` with Mixamo names + NLA clips.
3. Add a GLB section to `scripts/tests/integration_test.gd` (clips, ≥60 tracks, no Slide/Dash).
4. Update `docs/status.md`, the character dossier's *Implementation status*, and the table above.
