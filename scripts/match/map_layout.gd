class_name MapLayout
extends RefCounted

## Reads a map scene's match nodes (docs/RESBAK.md § 5 "Nodes"): base sites, jails, jail
## markers, spawns, and marks vaultable props. Accepts the spec names (BaseSite_Dilaw_1,
## Jail_Dilaw, JailMarker_Dilaw, Spawn_Dilaw_1 ...) and the Barangay Court's older names
## (BaseSites/Yellow_Site_1, JailZones/YellowJail). Anything missing is derived, so a grey
## test map with only sites and jails still plays.
## "Jail of team T" = the jail on T's side, where T's taggers send enemies (Jail_Dilaw holds Lila).

const VAULTABLE_PREFIXES := ["WoodenCrate", "TireStack", "BluePlasticChair", "TarpaulinBundle", "MetalBarrier", "PottedPlant", "StageFrontCrate", "RearTireStack", "RearChair", "FrontFence"]

var root: Node3D
var sites := [[], []] ## per team: Array[Vector3] for site numbers 1..3 (index 0..2)
var jail_rects := [Rect2(), Rect2()] ## per owning team, XZ
var jail_y := [0.0, 0.0]
var markers := [Vector3.ZERO, Vector3.ZERO]
var out_dirs := [Vector3.RIGHT, Vector3.LEFT] ## from each jail toward its prisoners' home
var spawns := [[], []] ## per team: Array[Vector3] (spawn 1, spawn 2)
var bounds := Rect2(-19.5, -11.5, 39.0, 29.0) ## playable XZ area (camera, bots)
var pole_nodes := [[], []] ## scene meshes that draw each team's pole (moved to the active site)
var vaultables: Array[StaticBody3D] = []

static func from_map(map_root: Node3D) -> MapLayout:
	var m := MapLayout.new()
	m.root = map_root
	m._read()
	return m

func _find(node_name: String) -> Node3D:
	return root.find_child(node_name, true, false) as Node3D

func _read() -> void:
	var legacy_team := ["Yellow", "Purple"]
	var spec_team := ["Dilaw", "Lila"]
	for t in range(2):
		for n in range(1, 4):
			var node := _find("BaseSite_%s_%d" % [spec_team[t], n])
			if node == null:
				node = _find("%s_Site_%d" % [legacy_team[t], n])
			if node:
				sites[t].append(RB.flat(node.global_position))
		var jail := _find("Jail_%s" % spec_team[t])
		if jail == null:
			jail = _find("%sJail" % legacy_team[t])
		var size := Vector2(6.0, 4.0)
		var centre := Vector3((-16.6 if t == RB.DILAW else 16.6), 0, 0)
		if jail:
			centre = jail.global_position
			for cs in jail.find_children("*", "CollisionShape3D", true, false):
				var box := (cs as CollisionShape3D).shape as BoxShape3D
				if box:
					size = Vector2(box.size.x, box.size.z)
					break
		jail_rects[t] = Rect2(centre.x - size.x / 2.0, centre.z - size.y / 2.0, size.x, size.y)
		jail_y[t] = 0.0
		out_dirs[t] = Vector3.RIGHT if t == RB.DILAW else Vector3.LEFT
		var mk := _find("JailMarker_%s" % spec_team[t])
		if mk:
			markers[t] = RB.flat(mk.global_position)
		else:
			var r: Rect2 = jail_rects[t]
			var edge_x := r.end.x if t == RB.DILAW else r.position.x
			markers[t] = Vector3(edge_x, 0, r.get_center().y)
		for n in range(1, 3):
			var sp := _find("Spawn_%s_%d" % [spec_team[t], n])
			if sp:
				spawns[t].append(RB.flat(sp.global_position))
		if spawns[t].size() < 2:
			spawns[t] = _derived_spawns(t)
		for pole_name in ["%sPole" % legacy_team[t], "%sFlag" % legacy_team[t], "%sFoot" % legacy_team[t]]:
			var p := _find(pole_name)
			if p:
				pole_nodes[t].append(p)
	if sites[0].is_empty() or sites[1].is_empty():
		push_warning("MapLayout: map has no base sites; using defaults")
		sites = [[Vector3(-12, 0, 0)], [Vector3(12, 0, 0)]]

func _derived_spawns(t: int) -> Array:
	var r: Rect2 = jail_rects[t]
	var x := r.get_center().x
	return [Vector3(x - (0.9 if t == RB.DILAW else -0.9), 0, 2.5), Vector3(x - (0.9 if t == RB.DILAW else -0.9), 0, -1.0)]

# ---- queries ---------------------------------------------------------------------------
func site(team: int, number: int) -> Vector3:
	var list: Array = sites[team]
	return list[clampi(number - 1, 0, list.size() - 1)]

func site_count(team: int) -> int:
	return sites[team].size()

func jail_rect(owner_team: int) -> Rect2:
	return jail_rects[owner_team]

func jail_centre(owner_team: int) -> Vector3:
	var c: Vector2 = (jail_rects[owner_team] as Rect2).get_center()
	return Vector3(c.x, 0, c.y)

func marker(owner_team: int) -> Vector3:
	return markers[owner_team]

func out_dir(owner_team: int) -> Vector3:
	return out_dirs[owner_team]

## Spec: hand point = 1.5 m outside the barrier, straight out from the marker.
func hand_point(owner_team: int, offset: float) -> Vector3:
	return markers[owner_team] + out_dirs[owner_team] * offset

func in_jail(owner_team: int, p: Vector3, margin := 0.0) -> bool:
	return (jail_rects[owner_team] as Rect2).grow(margin).has_point(Vector2(p.x, p.z))

## Random free spot inside a jail, at least `spacing` from `taken` positions if possible.
func random_jail_spot(owner_team: int, rng: RandomNumberGenerator, taken: Array, radius: float, spacing := 0.9) -> Vector3:
	var r := (jail_rects[owner_team] as Rect2).grow(-radius - 0.05)
	var best := Vector3(r.get_center().x, 0, r.get_center().y)
	var best_d := -1.0
	for i in range(24):
		var p := Vector3(rng.randf_range(r.position.x, r.end.x), 0, rng.randf_range(r.position.y, r.end.y))
		var d := 99.0
		for q in taken:
			d = minf(d, RB.flat_dist(p, q))
		if d >= spacing:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best

## Nearest point just outside a jail's barrier (rescued prisoners still inside move here).
func nearest_outside(owner_team: int, p: Vector3, radius: float) -> Vector3:
	var r := (jail_rects[owner_team] as Rect2).grow(radius + 0.05)
	if not r.has_point(Vector2(p.x, p.z)):
		return p
	var dl := p.x - r.position.x
	var dr := r.end.x - p.x
	var dt := p.z - r.position.y
	var db := r.end.y - p.z
	var m := minf(minf(dl, dr), minf(dt, db))
	if m == dl:
		return Vector3(r.position.x, p.y, p.z)
	if m == dr:
		return Vector3(r.end.x, p.y, p.z)
	if m == dt:
		return Vector3(p.x, p.y, r.position.y)
	return Vector3(p.x, p.y, r.end.y)

## Put small props on the vaultable layer (LUSOT! vaults them; everyone else collides).
func mark_vaultables() -> void:
	var props := root.find_child("CourtProps", true, false)
	if props == null:
		return
	for prop in props.get_children():
		var is_vault := false
		for prefix in VAULTABLE_PREFIXES:
			if String(prop.name).begins_with(prefix):
				is_vault = true
				break
		if not is_vault:
			continue
		for body in prop.find_children("*", "StaticBody3D", true, false):
			var sb := body as StaticBody3D
			sb.collision_layer = RB.L_VAULTABLE
			sb.add_to_group("vaultable")
			vaultables.append(sb)
