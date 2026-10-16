class_name MapLayout
extends RefCounted

## Reads a map scene's match nodes (docs/RESBAK.md § 5 "Nodes"): base sites, jails, jail
## markers, spawns, and marks vaultable props. Accepts the spec names (BaseSite_Dilaw_1,
## Jail_Dilaw, JailMarker_Dilaw, Spawn_Dilaw_1 ...) and the Barangay Court's older names
## (BaseSites/Yellow_Site_1, JailZones/YellowJail). Anything missing is derived, so a grey
## test map with only sites and jails still plays.
## "Jail of team T" = the jail on T's side, where T's taggers send enemies (Jail_Dilaw holds Lila).
## v0.2 jail line: JailLine_<team> (a Path3D anywhere in the map, any shape: straight, angled,
## snaking) runs along the map's end on T's side. The jail post slides along it and "in jail"
## means within tuning.jail_band of it (see JailSystem). A map without a line gets a straight
## one along the back of its Jail_<team> box (or the default yard).
## v0.2 fixed bases: each team has one base, BaseSite_<team> (or site 1 of the older
## numbered sites). A `Gameplay` node may carry metadata/play_bounds (Rect2, XZ) for the
## camera, minimap, bots and the chain.

## Props LUSOT! can vault (matched case-insensitively against the prop's node name).
const VAULTABLE_WORDS := ["crate", "tire", "chair", "tarpaulin", "barrier", "plant", "fence"]

var root: Node3D
var sites := [[], []] ## per team: Array[Vector3]; v0.2 uses only the first (fixed base)
var jail_rects := [Rect2(), Rect2()] ## per owning team, XZ: bounding box of the jail band
var lines := [PackedVector3Array(), PackedVector3Array()] ## per owning team: the jail line (flat polyline)
var line_cum := [PackedFloat32Array(), PackedFloat32Array()] ## distance along the line at each point
var jail_y := [0.0, 0.0]
var markers := [Vector3.ZERO, Vector3.ZERO] ## the jail post, per owning team
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
		var fixed := _find("BaseSite_%s" % spec_team[t])
		if fixed:
			sites[t].append(RB.flat(fixed.global_position))
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
					var k := (cs as Node3D).global_basis.get_scale()
					size = Vector2(box.size.x * k.x, box.size.z * k.z)
					break
		jail_rects[t] = Rect2(centre.x - size.x / 2.0, centre.z - size.y / 2.0, size.x, size.y)
		jail_y[t] = 0.0
		out_dirs[t] = Vector3.RIGHT if t == RB.DILAW else Vector3.LEFT
		var mk := _find("JailMarker_%s" % spec_team[t])
		if mk:
			markers[t] = RB.flat(mk.global_position)
		else: # the post stands at the back of the yard, away from the prisoners' home
			var r: Rect2 = jail_rects[t]
			var back_x := r.position.x + 0.6 if t == RB.DILAW else r.end.x - 0.6
			markers[t] = Vector3(back_x, 0, r.get_center().y)
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
	var gameplay := _find("Gameplay")
	if gameplay and gameplay.has_meta("play_bounds"):
		bounds = gameplay.get_meta("play_bounds")
	for t in range(2):
		_read_line(t, spec_team[t])

## The jail line, flattened, plus the derived post, yard box and out direction.
func _read_line(t: int, team_name: String) -> void:
	var pts := PackedVector3Array()
	var path := _find("JailLine_%s" % team_name) as Path3D
	if path and path.curve and path.curve.point_count >= 2:
		for q in path.curve.get_baked_points():
			var w := path.global_transform * q
			pts.append(Vector3(w.x, 0, w.z))
	if pts.size() < 2: # a straight line along the back of the yard
		var r: Rect2 = jail_rects[t]
		var x: float = markers[t].x
		pts = PackedVector3Array([Vector3(x, 0, r.position.y), Vector3(x, 0, r.end.y)])
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	lines[t] = pts
	line_cum[t] = cum
	var box := Rect2(Vector2(pts[0].x, pts[0].z), Vector2.ZERO)
	for q in pts:
		box = box.expand(Vector2(q.x, q.z))
	jail_rects[t] = box.grow(Tuning.get_default().jail_band)
	var mid := line_length(t) * 0.5
	markers[t] = line_point(t, mid)
	out_dirs[t] = line_normal(t, mid)

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

# ---- the jail line ----------------------------------------------------------------------
func line_length(owner_team: int) -> float:
	var cum: PackedFloat32Array = line_cum[owner_team]
	return cum[cum.size() - 1]

func _segment(owner_team: int, s: float) -> int:
	var cum: PackedFloat32Array = line_cum[owner_team]
	var i := cum.bsearch(clampf(s, 0.0, cum[cum.size() - 1]), true) - 1
	return clampi(i, 0, cum.size() - 2)

## The point `s` metres along the line (clamped to its ends).
func line_point(owner_team: int, s: float) -> Vector3:
	var pts: PackedVector3Array = lines[owner_team]
	var cum: PackedFloat32Array = line_cum[owner_team]
	var i := _segment(owner_team, s)
	var seg := cum[i + 1] - cum[i]
	var k := 0.0 if seg <= 0.0001 else clampf((s - cum[i]) / seg, 0.0, 1.0)
	return pts[i].lerp(pts[i + 1], k)

## Distance along the line of the line point nearest p.
func line_project(owner_team: int, p: Vector3) -> float:
	var pts: PackedVector3Array = lines[owner_team]
	var cum: PackedFloat32Array = line_cum[owner_team]
	var q := Vector3(p.x, 0, p.z)
	var best_s := 0.0
	var best_d := INF
	for i in range(pts.size() - 1):
		var a := pts[i]
		var ab := pts[i + 1] - a
		var l2 := ab.length_squared()
		var k := 0.0 if l2 < 0.000001 else clampf((q - a).dot(ab) / l2, 0.0, 1.0)
		var d := q.distance_squared_to(a + ab * k)
		if d < best_d:
			best_d = d
			best_s = cum[i] + k * sqrt(l2)
	return best_s

func line_distance(owner_team: int, p: Vector3) -> float:
	return RB.flat_dist(p, line_point(owner_team, line_project(owner_team, p)))

## Unit normal of the line at s, pointing into the field (toward the play-area centre).
func line_normal(owner_team: int, s: float) -> Vector3:
	var pts: PackedVector3Array = lines[owner_team]
	var i := _segment(owner_team, s)
	var tan := RB.flat(pts[i + 1] - pts[i])
	var n := Vector3(-tan.z, 0, tan.x).normalized() if tan.length() > 0.0001 else Vector3.RIGHT
	var c := bounds.get_center()
	var at := line_point(owner_team, s)
	if n.dot(Vector3(c.x - at.x, 0, c.y - at.z)) < 0.0:
		n = -n
	return n

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

## Within the jail band (tuning.jail_band) of the jail line.
func in_jail(owner_team: int, p: Vector3, margin := 0.0) -> bool:
	if not (jail_rects[owner_team] as Rect2).grow(margin).has_point(Vector2(p.x, p.z)):
		return false
	return line_distance(owner_team, p) <= Tuning.get_default().jail_band + margin

## Random free spot on the jail line, at least `spacing` from `taken` positions if possible.
func random_jail_spot(owner_team: int, rng: RandomNumberGenerator, taken: Array, _radius: float, spacing := 0.9) -> Vector3:
	var best: Vector3 = markers[owner_team]
	var best_d := -1.0
	for i in range(24):
		var p := line_point(owner_team, rng.randf_range(0.0, line_length(owner_team)))
		var d := 99.0
		for q in taken:
			d = minf(d, RB.flat_dist(p, q))
		if d >= spacing:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best

## Nearest point just outside a jail's band (rescued prisoners still inside move here).
func nearest_outside(owner_team: int, p: Vector3, radius: float) -> Vector3:
	var band := Tuning.get_default().jail_band + radius + 0.05
	var s := line_project(owner_team, p)
	var on := line_point(owner_team, s)
	if RB.flat_dist(p, on) >= band:
		return p
	var out := on + line_normal(owner_team, s) * band
	return Vector3(out.x, p.y, out.z)

## Put small props on the vaultable layer (LUSOT! vaults them; everyone else collides).
func mark_vaultables() -> void:
	var props := root.find_child("CourtProps", true, false)
	if props == null:
		return
	for prop in props.get_children():
		var is_vault := false
		var lower := String(prop.name).to_lower()
		for word in VAULTABLE_WORDS:
			if lower.contains(word):
				is_vault = true
				break
		if not is_vault:
			continue
		for body in prop.find_children("*", "StaticBody3D", true, false):
			var sb := body as StaticBody3D
			sb.collision_layer = RB.L_VAULTABLE
			sb.add_to_group("vaultable")
			vaultables.append(sb)
