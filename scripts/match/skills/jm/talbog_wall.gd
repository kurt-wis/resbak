extends SkillObject

## The crescent earth wall TALBOG! raises (docs/RESBAK.md § 4 JM). An arc of a circle (centre
## `arc_centre`, radius `arc_radius`, bulging along `forward`), `width` between its tips,
## `height` tall, built from box segments on one StaticBody3D on RB.L_SKILL_WALL (solid for
## everybody, blocks line of sight). The ends are open. Heroes overlapping it when it rises are
## moved to the nearer face. Collision is full size at once; the rise animation is cosmetic.

const THICKNESS := 0.6
const SEGMENTS := 9

var forward := Vector3(0, 0, 1)
var arc_centre := Vector3.ZERO
var arc_radius := 3.0
var half_angle := 1.0 ## radians either side of `forward`
var height := 1.5
var width := 5.0
var body: StaticBody3D
var visual: Node3D
var _right := Vector3(1, 0, 0)

## origin = landing point, dir = aim, offset = apex distance in front of the origin.
func build(origin: Vector3, dir: Vector3, p_width: float, offset: float, p_height: float) -> void:
	forward = RB.flat(dir).normalized()
	_right = Vector3(forward.z, 0.0, -forward.x)
	width = p_width
	height = p_height
	arc_radius = p_width * 0.6 # tips end up level with JM: a crescent that wraps round him
	half_angle = asin(clampf(p_width * 0.5 / arc_radius, 0.0, 1.0))
	arc_centre = RB.flat(origin) + forward * (offset - arc_radius)
	position = Vector3(0, origin.y, 0) # arc maths below is in world XZ; the object sits at the floor
	body = StaticBody3D.new()
	body.name = "WallBody"
	body.collision_layer = RB.L_SKILL_WALL
	body.collision_mask = 0
	add_child(body)
	visual = Node3D.new()
	visual.name = "WallVisual"
	add_child(visual)
	var earth := Vfx.flat_material(Color("8a6a46"), false)
	earth.cull_mode = BaseMaterial3D.CULL_BACK
	var top := Vfx.flat_material(Color("a98a5e"), false)
	top.cull_mode = BaseMaterial3D.CULL_BACK
	var seg_len := 2.0 * arc_radius * sin(half_angle / SEGMENTS) * 1.15
	for i in range(SEGMENTS):
		var th := -half_angle + 2.0 * half_angle * (i + 0.5) / SEGMENTS
		var local := _arc_point(th) # world XZ
		var yaw := atan2(_tangent(th).x, _tangent(th).z)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(THICKNESS, height, seg_len)
		cs.shape = box
		cs.position = Vector3(local.x, height * 0.5, local.z)
		cs.rotation.y = yaw
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		mi.mesh = bm
		mi.material_override = earth
		mi.position = cs.position
		mi.rotation.y = yaw
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		visual.add_child(mi)
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(THICKNESS * 1.15, 0.18, seg_len)
		cap.mesh = cm
		cap.material_override = top
		cap.position = Vector3(local.x, height + 0.05, local.z)
		cap.rotation.y = yaw
		visual.add_child(cap)

func _arc_point(theta: float) -> Vector3:
	return arc_centre + (forward * cos(theta) + _right * sin(theta)) * arc_radius

## Direction along the arc (increasing theta), flat unit.
func _tangent(theta: float) -> Vector3:
	return (-forward * sin(theta) + _right * cos(theta)).normalized()

func tip_points() -> Array[Vector3]:
	return [_arc_point(-half_angle), _arc_point(half_angle)]

## The wall's apex (middle of the arc).
func apex() -> Vector3:
	return _arc_point(0.0)

## True if a body of `radius` centred at `p` (world XZ used) overlaps the wall.
func overlaps(p: Vector3, radius: float) -> bool:
	var d := RB.flat(p) - arc_centre
	var r := d.length()
	if absf(r - arc_radius) >= THICKNESS * 0.5 + radius:
		return false
	var th := atan2(d.dot(_right), d.dot(forward))
	return absf(th) <= half_angle + (radius + THICKNESS * 0.5) / arc_radius * 0.5

## Move every Free hero that overlaps the wall to the nearer face. Returns the moved heroes.
func resolve_overlaps(heroes: Array[Hero], radius: float) -> Array[Hero]:
	var moved: Array[Hero] = []
	for h in heroes:
		if not h.is_free() or absf(h.global_position.y - global_position.y) > 1.0:
			continue
		if not overlaps(h.global_position, radius):
			continue
		var d := RB.flat(h.global_position) - arc_centre
		var r := d.length()
		var rn := (arc_radius - THICKNESS * 0.5 - radius - 0.03) if r < arc_radius else (arc_radius + THICKNESS * 0.5 + radius + 0.03)
		var p := arc_centre + d.normalized() * rn
		h.teleport(Vector3(p.x, h.global_position.y, p.z))
		moved.append(h)
	return moved

## Rise animation (presentation only).
func play_rise() -> void:
	if visual == null:
		return
	visual.scale = Vector3(1, 0.05, 1)
	var tw := visual.create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_expire() -> void:
	# Solid stops the moment it expires, even before the node leaves the tree.
	if body:
		body.collision_layer = 0
		for cs in body.get_children():
			if cs is CollisionShape3D:
				(cs as CollisionShape3D).disabled = true
	if visual and is_inside_tree():
		var parent := get_parent()
		var gp := visual.global_position
		remove_child(visual)
		if parent:
			parent.add_child(visual)
			visual.global_position = gp
			var tw := visual.create_tween()
			tw.tween_property(visual, "scale", Vector3(1, 0.02, 1), 0.3).set_ease(Tween.EASE_IN)
			tw.tween_callback(visual.queue_free)
		else:
			visual.queue_free()
