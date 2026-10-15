# Assets: where things live and how they flow

```
imported_models/<pack>/        raw prop packs (.glb + albedo + metallic/roughness PNG)
   └─ scripts/map_pipeline/prepare_props.gd ──► assets/props/<name>.tscn + <name>_geometry_1.res
source_art/<character>/        raw character sources (Godot-ignored)
   └─ tools/build_*.py (Blender) ─────────────► assets/characters/<name>.glb
assets/environment/            hand-painted textures used by shaders/*.gdshader
shaders/                       all spatial shaders (toon, outline, painted surfaces, roof cutaway, jail hologram)
```

## Props
8 props: `blue_plastic_chair` (from `blue_monobloc_chair_1k`), `metal_barrier`
(`crowd_barrier_1800tri`), `potted_plant`, `stage_speaker` (`barangay_speaker_900tri_clean`),
`street_tricycle` (`filipino_tricycle_5000tri`), `tarpaulin_bundle`, `tire_stack`, `wooden_crate`.
Each prop scene has a `SolidCollision` body matching its visible mesh.
`scenes/barangay_court.tscn` instances them under `CourtProps` and `StreetDetails`.

## Characters
Game-ready GLBs in `assets/characters/`; character visuals get `character_toon.gdshader`
applied at runtime (`court_playtest.gd: apply_illustrated_materials`).

## Godot sidecar files
- `*.import`: import settings next to every imported asset. Commit them; move them with their asset.
- `*.gd.uid` / `*.uid`: stable resource IDs. **Always move/rename with the `.gd`**.
- `.godot/`: local import cache, gitignored. Rebuild with `& $env:GODOT --headless --path . --import`.

## Git LFS policy (adopted 2026-10-15)
`.gitattributes` routes `*.glb *.png *.jpg *.blend *.res` through Git LFS.
History was **not** rewritten: binaries committed before 2026-10-15 stay as regular git
objects until they're next modified, then they become LFS pointers. Requires
`git lfs install` on each clone.
