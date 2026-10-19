class_name SkillAimView
extends Node3D

## Local-only skill intent. JM's committed flight telegraph lives in the actual skill.
## Every outline is drawn twice: a dark ink under-stroke, then the bright skill colour, so the
## shape reads on the light court, on grass and against props. Fills stay restrained, and the
## shape alone carries the meaning: no floating names, ranges or target markers.
const INK := Color("10131c")

var host: MatchHost
var local: Hero
var info := {}
var _signature := ""

func setup(value: MatchHost, hero: Hero) -> void:
	host = value
	local = hero
	name = "SkillAimPreview"
	visible = false

func refresh() -> void:
	var source := host.input_sources.get(local.slot) as PlayerInput if local else null
	if source == null or not source.enabled or source.touch_skill_button == 0 or not host.round_live() or not local.is_free():
		visible = false
		info = {}
		_signature = ""
		return
	var slot := 0 if source.touch_skill_button == RB.BTN_SKILL1 else 1
	var skill: Skill = local.skills[slot]
	if skill.active or not skill.can_cast():
		visible = false
		return
	var frame := source.skill_preview_frame(local)
	show_info(skill, skill.aim_preview(frame), local.global_position, source.touch_skill_cancelled)

## Also used by public committed tells, which share the same shape with no private extras.
func show_info(skill: Skill, preview: Dictionary, origin: Vector3, cancelled := false, committed := false) -> void:
	info = preview
	local = skill.hero
	var point: Vector3 = info.point
	var dir: Vector3 = info.direction
	var key := "%s/%d/%.2f/%.2f/%.2f/%.2f/%.2f/%.2f/%s/%d/%s" % [local.data.id, skill.slot, origin.x, origin.z, point.x, point.z, dir.x, dir.z, str(cancelled), host.objects.size(), str(committed)]
	visible = true
	if key == _signature:
		return
	_signature = key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# The colour alone tells the state: red = releasing here cancels, amber = blocked, cyan = max range.
	var color: Color = info.color.lerp(Color.WHITE, 0.45)
	if cancelled:
		color = Color("ef4444")
	elif info.get("blocked", false):
		color = Color("ffb066")
	elif info.get("clamped", false):
		color = Color("6ee7ff")
	color.a = host.tuning.skill_preview_outline_alpha
	var fill := Color(color.r, color.g, color.b, host.tuning.skill_preview_fill_alpha)
	var width := host.tuning.skill_preview_line_width
	match str(info.mode):
		"point":
			_ring(origin, float(info.range), Color(color.r, color.g, color.b, 0.3), width * 1.2)
			_ring(point, float(info.radius), color, width * 2.0, fill.a, "LandingArea")
			for segment in info.wall:
				var box := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = segment.size
				box.mesh = mesh
				box.material_override = Vfx.flat_material(Color(color.r, color.g, color.b, host.tuning.skill_preview_wall_alpha))
				box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(box)
				box.global_position = segment.position
				box.rotation.y = segment.yaw
				box.name = "WallGhost_%d" % get_child_count()
			var previous := origin
			for i in range(1, 25):
				var t := i / 24.0
				var next: Vector3
				if local.data.id == "jm":
					next = skill.sample_arc(origin, point, t, float(skill.v("talbog_jump_height")))
				else:
					next = UboPacket.sample_arc(info.trajectory_from, info.trajectory_to, t)
				if i > 1:
					_stroke(previous, next, width, color)
				previous = next
		"cone":
			_cone(origin, dir, float(info.distance), float(info.angle), fill, color, width)
		"line", "lane", "path":
			var length: float = info.distance
			if length > width * 2.0:
				_shape(Vfx.lane_mesh(length, float(info.width), fill), origin, dir, 0.04)
				_shape(Vfx.tag_strip_border(length, float(info.width) * 0.5, width * 1.9, Color(INK.r, INK.g, INK.b, host.tuning.skill_preview_ink_alpha)), origin, dir, 0.05)
				_shape(Vfx.tag_strip_border(length, float(info.width) * 0.5, width, color), origin, dir, 0.075)
				# Ink-outlined direction arrow, sized to read from the match camera.
				var arrows := Vfx.aim_arrow_meshes(length * 0.55, width * 3.0, width * 14.0, width * 9.0, length * 0.28, 1.35, width * 1.9)
				for i in range(2):
					var arrow := MeshInstance3D.new()
					arrow.mesh = arrows[i]
					arrow.material_override = Vfx.flat_material(Color(INK.r, INK.g, INK.b, host.tuning.skill_preview_ink_alpha) if i == 1 else color)
					arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					arrow.name = "LaneArrow"
					_shape(arrow, origin, dir, 0.05 if i == 1 else 0.075)
			if info.icon == "hand":
				_ring(point, float(info.radius), color, width * 1.6)
		"self":
			pass # a self buff gets an overhead cue, not a fake ground area

func _cone(origin: Vector3, dir: Vector3, length: float, angle: float, fill: Color, color: Color, width: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := origin
	var half := deg_to_rad(angle) * 0.5
	for i in range(33):
		var ray := dir.rotated(Vector3.UP, -half + 2.0 * half * i / 32.0)
		var hit := host.ray_hit(origin, origin + ray * length, RB.L_WORLD | RB.L_SKILL_WALL)
		var distance := length if hit.is_empty() else minf(length, RB.flat_dist(origin, hit.position))
		var end := origin + ray * distance
		if i > 0:
			for vertex in [origin, previous, end]:surface.add_vertex(vertex - origin + Vector3.UP * 0.03)
			_stroke(previous, end, width, color)
		if i == 0 or i == 32:
			_stroke(origin, end, width, color)
		previous = end
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = Vfx.flat_material(fill)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	mesh.global_position = origin
	# A short centre arrow shows the committed direction at a glance.
	var arrow := Vfx.arrow_mesh(minf(length, 2.4), width * 1.6, width * 8.0, width * 5.5, color)
	_shape(arrow, origin + dir * maxf(length - 2.2, 0.0), dir)

func _ring(at: Vector3, radius: float, color: Color, width: float, filled_alpha := 0.0, node_name := "") -> void:
	var ink := Vfx.ground_ring(self, at - Vector3.UP * 0.01, radius, Color(INK.r, INK.g, INK.b, host.tuning.skill_preview_ink_alpha), width * 2.2)
	ink.name = "RingInk"
	var bright := Vfx.ground_ring(self, at + Vector3.UP * 0.012, radius, color, width, filled_alpha)
	bright.name = node_name if node_name != "" else "Ring"

func _shape(mesh: MeshInstance3D, origin: Vector3, dir: Vector3, lift := 0.08) -> void:
	add_child(mesh)
	mesh.global_position = origin + Vector3.UP * lift
	mesh.rotation.y = atan2(dir.x, dir.z)

## Comic stroke: dark under-stroke first, bright stroke on top, both flat on the ground.
func _stroke(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.001:
		return
	_box(from, to, width * host.tuning.skill_preview_ink_scale, Color(INK.r, INK.g, INK.b, host.tuning.skill_preview_ink_alpha), 0.055)
	_box(from, to, width, color, 0.075)

func _box(from: Vector3, to: Vector3, width: float, color: Color, lift: float) -> void:
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.02, from.distance_to(to))
	line.mesh = mesh
	line.material_override = Vfx.flat_material(color)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	line.global_position = (from + to) * 0.5 + Vector3.UP * lift
	line.look_at(to + Vector3.UP * lift, Vector3.RIGHT if absf((to - from).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
