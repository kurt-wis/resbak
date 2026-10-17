# source_art/ — raw inputs for the Blender pipeline (not loaded by Godot)

`.gdignore` keeps Godot from importing anything here. Game-ready outputs live in `assets/`.

| Folder | Contents | Consumed by |
| ------ | -------- | ----------- |
| `batang_hamog/` | Original high-res mesh + Mixamo rig (`BatangHamog.glb`) and its textures | `tools/build_batang_hamog.py` |
| `jm_botsog/` | `jm_botsog.blend` working file | **written** by `tools/build_jm_botsog.py` (for manual inspection in Blender) |
| `heroes/` | The five Meshy hero GLBs (Mixamo-named rigs) + `KimKim_Asset.glb` prop | `tools/build_heroes.py` |
| `props/vehicles/` | Mathew's Meshy vehicle downloads (2026-10-17): `jeepney`, `pickup`, `hauler`, `digger`, `wheel_loader` (**AI-assisted**, Meshy, made by Mathew) | `tools/build_vehicle_props.py` |
| `mocap/quaternius/` | `UAL1_Standard.glb`, Quaternius Universal Animation Library (in place, no root motion). **CC0**, by Quaternius (quaternius.com) | `tools/build_heroes.py` (Push_Loop → Capture) |
| `mocap/meshy/` | Meshy clips on Meshy's own 24-bone rig (**AI-assisted**: each hero auto-rigged by Meshy from its source GLB, preset animations applied per hero, plus two text-to-motion clips; team Meshy account, 2026-10-16, 147 credits; log on Form 03). Clips per file below | `tools/build_heroes.py` via `tools/retarget_clip.py` |

Files in `mocap/meshy/` (clip names as Meshy exported them; `build_heroes.py` picks them by name):

| File | Rig | Clips |
| ---- | --- | ----- |
| `tutoy_moves.glb` | Tutoy | Idle_5, Quick_Walk, Lean_Forward_Sprint, run_fast_2, slide_light, Unarmed_Vault (Tutoy's own); Slap_Reaction, Stumble_Walk, Head_Hold_in_Pain, Wave_for_Help (shared Tagged, Stumble, Stunned, Jailed) |
| `nene_moves.glb` | Nene | Happy_Sway_Standing, Skip_Forward, run_fast_7, Angry_To_Tantrum_Sit (Iyak), Call_Gesture (Sumbong); Victory_Cheer (shared Victory) |
| `nathan_moves.glb` | Nathan | Scheming_Hand_Rub, Sneaky_Walk, run_fast_9, Over_Shoulder_Throw (Ubo) |
| `nathan_buga.glb` | Nathan | Text-to-motion: lean back to inhale, then blow forward (Buga) |
| `jm_moves.glb` | JM | Idle_11, Proud_Strut, run_fast_4, Regular_Jump (Talbog_Jump), Charged_Ground_Slam (Talbog_Slam), Male_Head_Down_Charge (Tamaraw), Hit_Reaction_to_Waist (GuardBreak) |
| `inday_moves.glb` | Inday | Hand_on_Hip_Gesture, Confident_Strut, run_fast_6, mage_soell_cast_3 (Ihip), Cheer_with_Both_Hands_Up (Sagip) |
| `shared_tag.glb` | Nathan | Text-to-motion: wind-up, lunge and reach to tag (shared Tag) |
| `shared_tag_charge.glb` | SMPL-H (52 bones) | Text-to-motion, Meshy Prime, 2026-10-17, 10 credits, task `01a149eb-4d53-752c-9369-c6faf97fa4d3`: wide-stance held slap wind-up, 2 s loop (shared TagCharge). Converted from Meshy's FBX |

The Mixamo breakdance pack lives in the repo-root `mixamo/` folder (Sukuna drops new Mixamo downloads there; it has its own `.gdignore`).
