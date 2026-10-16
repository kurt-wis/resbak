# Map pipeline (historical, destructive)

`scenes/barangay_court.tscn` was built up by a series of one-shot `extends SceneTree`
scripts, now in [`scripts/map_pipeline/`](../../scripts/map_pipeline/). Each loads its
target, mutates it, and **overwrites it on disk**. They are already applied; the
scene file is the source of truth. **Edit the scene directly; don't re-run these.**

The original run order was not recorded. All of them landed in the initial commit (`a39ae3f`).

| Script | Overwrites | What it did |
| ------ | ---------- | ----------- |
| `prepare_props.gd` | `assets/props/*.tscn` + `*_geometry_1.res` | Wraps each `imported_models/<pack>/*.glb` into a prop scene with a `SolidCollision` body (catalog: name → pack, scale). |
| `prepare_concrete_texture.gd` | `assets/environment/painted_concrete_tile.res` | Mipmapped `ImageTexture` from `painted_concrete_tile.png`. |
| `build_roof.gd` | `scenes/court_roof.tscn` | Corrugated roof slopes, trusses, warm lamps, `cutaway_roof.gdshader`. |
| `build_neighborhood.gd` | `barangay_court.tscn` | `NeighborhoodSurroundings` houses + raised sidewalk around the court. |
| `cleanup_court.gd` | `barangay_court.tscn` | Removed clutter/sign, rebuilt sidewalk, curbs, ramps, concrete joints, jail zones. |
| `refine_perimeter.gd` | `barangay_court.tscn` | Pillars (blue pedestal + cream shaft), curbs, ramp collisions. |
| `fix_ramp_faces.gd` | `barangay_court.tscn` | Ramp face / collision orientation at x = ±7. |
| `fix_walkway_ramps.gd` | `barangay_court.tscn` | Continuous walkway collision + access landings. |
| `remove_duplicate_collisions.gd` | `barangay_court.tscn` | Dropped duplicate tricycle collision bodies under `StreetDetails`. |
| `populate_litter.gd` | `barangay_court.tscn` | `StreetLitter` scatter (fixed seeds 11, 31, 47, 81, 19, 99). |
| `texture_architecture.gd` | `barangay_court.tscn` | `painted_architecture.gdshader` on walls/pillars. |
| `final_map_refinement.gd` | `barangay_court.tscn` | Pillar collisions joined, roof removed from court, stage wood, jail tweaks. |
| `cartoon_environment_pass.gd` | `barangay_court.tscn` | Shared cartoon wall paint, `cartoon_stage_wood`, dusty front alley, `PaintedWallGraffiti`. |
| `unify_map_materials.gd` | `barangay_court.tscn` | One `ContinuousWallAndPillarPaint` masonry material, illustrated stage wood. |

## Current top-level layout of `barangay_court.tscn`
`CourtFloor`, `Architecture`, `CourtProps` (56 prop instances), `BaseSites`
(`Yellow_Site_1..3`, `Purple_Site_1..3`: `Area3D`), `JailZones` (`YellowJail`,
`PurpleJail`: `Area3D`), `StreetDetails` (incl. `PurpleStreetTricycle`), `StreetLitter`,
`NeighborhoodSurroundings`, `PaintedWallGraffiti`. **No `CourtRoof` node**;
`scenes/court_roof.tscn` exists separately but nothing currently instances it.

## Match markers a map needs (v0.2)
- `BaseSite_Dilaw` and `BaseSite_Lila` (any Node3D): the one fixed base per team. Older maps fall back to site 1 of `BaseSites/{Yellow,Purple}_Site_N`.
- `JailLine_Dilaw` and `JailLine_Lila` (`Path3D`, anywhere): the jail line on that team's end (the jail of team T holds T's prisoners' enemies). Any shape: straight, angled or snaking; `MapLayout` samples the curve. Without one, a straight line is derived along the back of the old jail box.
- Optional `Gameplay` node with `metadata/play_bounds` (Rect2, XZ) for the camera, minimap, bots and chain.
- `scenes/construction_site.tscn` (Konstruksyon) carries its own WorldEnvironment; `MapDressing` leaves its lighting alone.

The old `scripts/tests/legacy/verify_*.gd` checks were snapshots taken between these
passes and no longer match the map (see `scripts/tests/README.md`).
