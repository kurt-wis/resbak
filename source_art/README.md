# source_art/ — raw inputs for the Blender pipeline (not loaded by Godot)

`.gdignore` keeps Godot from importing anything here. Game-ready outputs live in `assets/`.

| Folder | Contents | Consumed by |
| ------ | -------- | ----------- |
| `batang_hamog/` | Original high-res mesh + Mixamo rig (`BatangHamog.glb`) and its textures | `tools/build_batang_hamog.py` |
| `jm_botsog/` | `jm_botsog.blend` working file | **written** by `tools/build_jm_botsog.py` (for manual inspection in Blender) |
