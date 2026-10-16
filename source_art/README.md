# source_art/ — raw inputs for the Blender pipeline (not loaded by Godot)

`.gdignore` keeps Godot from importing anything here. Game-ready outputs live in `assets/`.

| Folder | Contents | Consumed by |
| ------ | -------- | ----------- |
| `batang_hamog/` | Original high-res mesh + Mixamo rig (`BatangHamog.glb`) and its textures | `tools/build_batang_hamog.py` |
| `jm_botsog/` | `jm_botsog.blend` working file | **written** by `tools/build_jm_botsog.py` (for manual inspection in Blender) |
| `heroes/` | The five Meshy hero GLBs (Mixamo-named rigs) + `KimKim_Asset.glb` prop | `tools/build_heroes.py` |
| `mocap/quaternius/` | `UAL1_Standard.glb`, Quaternius Universal Animation Library (in place, no root motion). **CC0**, by Quaternius (quaternius.com) | `tools/build_heroes.py` (Idle_Loop, Jog_Fwd_Loop) |

The Mixamo breakdance pack lives in the repo-root `mixamo/` folder (Sukuna drops new Mixamo downloads there; it has its own `.gdignore`).
