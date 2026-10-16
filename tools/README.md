# tools/ — Blender 5.2 headless builders

All scripts are pure `bpy`, run from the repo root, and resolve paths relative to
this folder (no hardcoded machine paths).

```powershell
& $env:BLENDER -b --python tools/<script>.py
```

| Script | Input | Output | Status |
| ------ | ----- | ------ | ------ |
| `build_batang_hamog.py` | `source_art/batang_hamog/BatangHamog.glb` | `assets/characters/batang_hamog.glb` locomotion only: Idle/Walking/Running/RunFast | **Stage 1** — rebuilds from raw source. Running it alone strips Harurot/Lusot (gate fails until stage 2). |
| `build_hamog_moveset.py` | `assets/characters/batang_hamog.glb` (in place) | same file: purges Slide/Dash/Roll, authors `Harurot`, `Lusot_Slide`, `Lusot_Vault` | **Stage 2** — run after stage 1. |
| `build_heroes.py` | `source_art/heroes/*_Character.glb`, Meshy clips `source_art/mocap/meshy/*.glb`, Quaternius `source_art/mocap/quaternius/UAL1_Standard.glb` (Capture), Mixamo `mixamo/breakdance-pack/*.fbx` | `assets/characters/{tutoy,nene,nathan,jm,inday}.glb`: each hero's own Idle/Walking/Running and skill clips, the shared core-rule clips (Tag, Tagged, Stumble, Stunned, Jailed, Chained, Capture, Victory), a looping Mixamo BreakDance; `renders/heroes_<id>_{idle,walking,running,moves}.png`, `renders/heroes_breakdance.png` | One clip table per hero (`HERO_CLIPS`) plus `SHARED`; clip lists in `docs/pipelines/blender.md`. `-- <id>` builds one hero (~30 s each). |
| `retarget_clip.py` | a Meshy GLB (its own 24-bone rig), Mixamo FBX or Quaternius GLB clip + a hero armature | offset frames for `build_heroes.bake()` | Library used by `build_heroes.py`; run alone (`-- <clip file>`) to list its clips and bone mapping. |
| `qc_asset.py` | any .glb/.fbx | `renders/qc/<name>_sheet.png` + `_qc.json` | 4-view solid+wire sheet and checks: ground, centre, facing, normals, tris, Mixamo names, clip loop seam and foot slide (`--speed Running=5.4`). Exit 1 on FAIL. |
| `sanitize_asset.py` | raw Meshy/downloaded prop | `assets/props/<name>.glb` | Bake transforms, fix normals, scale (`--size`), origin bottom or center, decimate (`--max-tris`). |
| `build_jm_botsog.py` | none (fully procedural) | `assets/characters/jm_botsog.glb`, `source_art/jm_botsog/jm_botsog.blend`, `renders/jm_*.png`, `renders/jm_build_meta.json` | JM model + Idle/Walking/Running. |

After any rebuild, run the integration gate. Details and rig rules:
[`docs/pipelines/blender.md`](../docs/pipelines/blender.md).
