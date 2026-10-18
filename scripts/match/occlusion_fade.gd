class_name OcclusionFade
extends Node

## Camera occlusion (2026-10-17, Konstruksyon pass). The match camera is a fixed 35 degree
## orthographic view, so a tall prop between it and the local hero (a truck, the shed, a palm)
## swallows them. Every frame the segment from the camera to the hero's head is tested against the
## bounds of each tall prop group; the groups it crosses fade to see-through and come back when the
## hero steps clear. The Compatibility renderer ignores GeometryInstance3D.transparency, so each
## surface swaps to an alpha-blended duplicate of its StandardMaterial3D while it is fading.
## Presentation only: it never touches collision, the host or an InputFrame. A map opts in with
## `occlusion_fade = true` on its Gameplay node (Barangay Court has its own roof cutaway).

const MIN_HEIGHT := 2.0 ## props shorter than this never hide a hero
const MAX_FOOTPRINT := 14.0 ## bigger meshes are merged ground decor, not props
const NEAR_PLAY := 10.0 ## props this far outside the play bounds still count (camera side)
const FADED := 0.78 ## how see-through a faded prop is (22 % visible)
const FADE_SPEED := 5.0 ## fade units per second
const PILE_GROW := 0.8 ## loose stones spill past a pile's collider by about this much
const GROW := 0.45 ## metres the prop bounds are inflated by for the hit test

var camera: Camera3D
var target: Node3D
var enabled := true
## Each: {name, meshes: Array[GeometryInstance3D], aabb: AABB, t: float, mats: Dictionary}
## (mats: MeshInstance3D -> [{surface, original, faded}], built the first time a prop fades.)
var groups: Array = []

## Opt-in flag read from the map (Gameplay.occlusion_fade).
static func wanted(map_root: Node) -> bool:
	var g := map_root.get_node_or_null("Gameplay")
	return g != null and bool(g.get_meta("occlusion_fade", false))

func setup(p_camera: Camera3D, map_root: Node3D, p_target: Node3D, bounds: Rect2) -> void:
	camera = p_camera
	target = p_target
	groups.clear()
	var area := bounds.grow(NEAR_PLAY) if bounds.size != Vector2.ZERO else Rect2(-1000, -1000, 2000, 2000)
	for group in map_root.get_children():
		if not (group is Node3D) or group.name in ["Gameplay", "Ground", "Water", "Boats", "YardWalls", "LightingAndEnvironment"]:
			continue
		for prop in group.get_children():
			if prop is Node3D and not (prop is StaticBody3D):
				_add_prop(prop, area)

func _add_prop(prop: Node3D, area: Rect2) -> void:
	var meshes: Array = []
	var box := AABB()
	var first := true
	var stack: Array[Node] = [prop]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var a := AABB()
		var has := false
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi := n as MeshInstance3D
			meshes.append(mi)
			a = mi.global_transform * mi.mesh.get_aabb()
			has = true
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			meshes.append(n) # instanced stones: bounded by the pile's collider below
		elif n is CollisionShape3D and _has_multimesh(prop) and (n as CollisionShape3D).shape is CylinderShape3D:
			var cs := n as CollisionShape3D
			var cyl := cs.shape as CylinderShape3D
			a = cs.global_transform * AABB(Vector3(-cyl.radius, -cyl.height * 0.5, -cyl.radius), Vector3(cyl.radius * 2.0, cyl.height, cyl.radius * 2.0))
			a = AABB(a.position - Vector3(PILE_GROW, 0, PILE_GROW), a.size + Vector3(PILE_GROW * 2.0, 0, PILE_GROW * 2.0))
			has = true
		if has:
			box = a if first else box.merge(a)
			first = false
		for c in n.get_children():
			stack.append(c)
	if meshes.is_empty() or first:
		return
	var foot := Vector2(box.size.x, box.size.z)
	if box.end.y < MIN_HEIGHT or maxf(foot.x, foot.y) > MAX_FOOTPRINT:
		return
	if not area.intersects(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)):
		return
	groups.append({"name": String(prop.name), "meshes": meshes, "aabb": box, "t": 0.0, "mats": {}})

func _has_multimesh(prop: Node) -> bool:
	return not prop.find_children("*", "MultiMeshInstance3D", true, false).is_empty()

func _process(delta: float) -> void:
	var flyover := camera is MatchCamera and (camera as MatchCamera).intro_w > 0.05
	refresh(delta, flyover)

## One presentation step. `hidden` forces everything back (round-1 flyover, no hero).
func refresh(delta: float, hidden := false) -> void:
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var active := enabled and not hidden and camera != null and is_instance_valid(camera) and target != null and is_instance_valid(target)
	if active:
		from = camera.global_position
		to = target.global_position + Vector3(0, 1.0, 0)
	for g in groups:
		var want := 0.0
		if active and (g.aabb as AABB).grow(GROW).intersects_segment(from, to):
			want = FADED
		var t: float = g.t
		var next := move_toward(t, want, FADE_SPEED * maxf(delta, 0.0)) if delta > 0.0 else want
		if is_equal_approx(next, t):
			continue
		g.t = next
		_apply(g)

## Show the group at its current fade: alpha duplicates while fading, the originals when clear.
func _apply(g: Dictionary) -> void:
	var t: float = g.t
	var mats: Dictionary = g.mats
	if mats.is_empty() and t > 0.0:
		for gi in g.meshes:
			var list: Array = []
			if gi is MultiMeshInstance3D:
				var mmi := gi as MultiMeshInstance3D
				var m0 := mmi.multimesh.mesh.surface_get_material(0) if mmi.multimesh.mesh else null
				if m0 is BaseMaterial3D:
					list.append({"surface": -1, "original": mmi.material_override, "faded": _fadeable(m0)})
			else:
				var mi := gi as MeshInstance3D
				for s in range(mi.mesh.get_surface_count()):
					var m := mi.get_active_material(s)
					if m is BaseMaterial3D:
						list.append({"surface": s, "original": mi.get_surface_override_material(s), "faded": _fadeable(m)})
			mats[gi] = list
	for gi in mats:
		if not is_instance_valid(gi):
			continue
		for e in mats[gi]:
			var shown: Material = e.original
			if t > 0.0:
				var f: BaseMaterial3D = e.faded
				var c := f.albedo_color
				c.a = 1.0 - t
				f.albedo_color = c
				shown = f
			if e.surface < 0:
				(gi as GeometryInstance3D).material_override = shown
			else:
				(gi as MeshInstance3D).set_surface_override_material(e.surface, shown)

func _fadeable(m: Material) -> BaseMaterial3D:
	var f := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
	f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	return f

## Names of the groups currently fading or faded (tests, debugging).
func faded_names() -> PackedStringArray:
	var out := PackedStringArray()
	for g in groups:
		if float(g.t) > 0.0:
			out.append(g.name)
	return out

func group_named(prop_name: String) -> Dictionary:
	for g in groups:
		if g.name == prop_name:
			return g
	return {}
