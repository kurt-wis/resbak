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
| `build_jm_botsog.py` | none (fully procedural) | `assets/characters/jm_botsog.glb`, `source_art/jm_botsog/jm_botsog.blend`, `renders/jm_*.png`, `renders/jm_build_meta.json` | JM model + Idle/Walking/Running. |

After any rebuild, run the integration gate. Details and rig rules:
[`docs/pipelines/blender.md`](../docs/pipelines/blender.md).
