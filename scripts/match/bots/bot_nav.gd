class_name BotNav
extends RefCounted

## Runtime navigation for bots (docs/RESBAK.md § 11 via the task brief): one NavigationMesh baked
## once per match from the static colliders under the map root (agent radius = body radius).
## v0.2: the jail posts slide along the jail line, so they are not carved out (the post barrier
## is enforced by JailSystem and bots steer around it like a player). It lives on
## its own navigation map, so several matches in one process (tests) never share a mesh.
## If baking gives nothing (no colliders, headless oddities), `ready` stays false and bots fall
## back to straight steering.

var map := RID()
var region := RID()
var ready := false
var polygons := 0
var _synced := false

## The nav for a host, baked on first use and kept on the host (freed with it).
static func of(host: MatchHost) -> BotNav:
	if host.has_meta("bot_nav"):
		return host.get_meta("bot_nav")
	var n := BotNav.new()
	n._bake(host)
	host.set_meta("bot_nav", n)
	return n

func _bake(host: MatchHost) -> void:
	if host.map_root == null:
		return
	var nm := NavigationMesh.new()
	nm.cell_size = 0.1 # agent_radius 0.4 = 4 whole cells
	nm.cell_height = 0.1
	nm.agent_radius = host.tuning.body_radius
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.3
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.geometry_collision_mask = RB.L_WORLD | RB.L_VAULTABLE
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, host.map_root)
	if not src.has_data():
		return
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	polygons = nm.get_polygon_count()
	if polygons == 0:
		return
	map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, nm.cell_size)
	NavigationServer3D.map_set_cell_height(map, nm.cell_height)
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_active(map, true)
	region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, nm)
	NavigationServer3D.region_set_transform(region, Transform3D.IDENTITY)
	NavigationServer3D.map_force_update(map)
	ready = true

## The server syncs a new map asynchronously, and the first iterations can come before the
## region has joined it (queries then answer the origin). Synced = the region owns the answers.
func synced() -> bool:
	if _synced:
		return true
	if not ready or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return false
	_synced = NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO) == region
	return _synced

## Path from `from` to `to` (corner points, first = start), or an empty array without a mesh.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not synced():
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(map, from, to, true)

## True if `p` is on (or within `tol` of) walkable ground. Always true without a mesh.
func walkable(p: Vector3, tol := 0.5) -> bool:
	if not synced():
		return true
	var c := NavigationServer3D.map_get_closest_point(map, p)
	return RB.flat_dist(c, p) <= tol

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if region.is_valid():
			NavigationServer3D.free_rid(region)
		if map.is_valid():
			NavigationServer3D.free_rid(map)
