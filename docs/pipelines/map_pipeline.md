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

## Reference environment pass (18 Oct 2026)

The existing `scenes/barangay_court.tscn` remains the map. `ReferenceDetails` instances
`scenes/barangay_reference_details.tscn`: individually editable Meshy trees, plants,
bench, vendor cart, traffic, streets, bins and bunting. The ten original concrete
court obstacles have individually visible painted meshes and their original
collision shapes; their duplicate faces were removed from the static batch.

`ReferenceCamera` is a separate perspective composition for the supplied 1886x834
reference. Its pose, FOV and resolution are in the root's `reference_camera`
metadata. Run the map directly for this view. `match.tscn` still removes map cameras
and uses MatchCamera with existing zoom/flip controls. ReferenceAfternoonSun and
ReferenceEnvironment are scene-local; MapDressing recognizes the environment and
avoids duplicate lighting. No project rendering settings changed.

With user approval, unwanted prop clusters and spare barriers moved together with
their colliders, and the center volleyball net assembly and collision were removed.
Other gameplay node paths, groups, signals, scripts, collision shapes and the
Gameplay subtree were preserved. Shared Meshy source resources are unchanged;
the cart's original small umbrella was trimmed in a scene-local mesh copy. Temporary
authoring helpers were removed. Do not re-run historical pipeline scripts.

Validation: full gate 15 suites / 1421 checks passed. Saved-scene checks verified
resources, prop persistence, ten barrier/collider pairs, three stair collision
surfaces, floor support and a character walking through the former net position.
Interactive movement, wheel zoom, camera flip and pause/resume were checked.
Baseline and final gate runs reported resource leaks on exit; baseline also
reported a talbog.gd teardown remove_child error.

## 19 Oct 2026 - Court visual consistency corrections

The mural artwork is not a seamless tile. Each visible wall, shelter backdrop and
barrier now has a scene-local fitted ShaderMaterial with its own mesh bounds.
The shader fits the full height, preserves the artwork's 3:1 aspect ratio and
mirrors long horizontal runs continuously. Narrow endcaps and tops use solid
paint. Refresh the editor's loaded Shader code before saving new uniform values;
writing the .gdshader file alone can leave its cached parameter list stale.

Side streets now have separate carriageways (6.55 m), planted verges and 3.2 m
outer sidewalks that stop at intersections. The original gravel render batch is
hidden, with rear/far verges shown individually. Original utility-pole, foot and
cable geometry stays intact. Existing sidewalk strips and duplicate furniture
that crossed the roads are hidden through local NeighborhoodBackdrop overrides.
Its shared source scene is unchanged. Tree MultiMeshes changed here are local
resource copies. New sidewalk furniture reuses individually editable Meshy props.

Traffic uses separate lanes, rests on the road, and clears all sidewalk furniture.
Stored chairs, tires, crates and spare barriers moved as whole parents with their
existing colliders onto two rear service aprons. Seven new slabs have matching
box colliders. The center remains open and original gameplay interfaces remain.

Validation: saved-scene mural/traffic/furniture/sidewalk/pole/collider assertions,
the original floor/stairs/barrier/center-walk checks, and a structural comparison
of original gameplay scripts, signals, groups and collision resources. Fresh
rendered views cover the barrier, shelter, both streets, rear and reference view.

