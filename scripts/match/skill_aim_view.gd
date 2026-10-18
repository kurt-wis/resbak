class_name SkillAimView
extends Node3D

## Local-only skill intent. JM's committed flight telegraph lives in the actual skill.
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
	info = skill.aim_preview(source.skill_preview_frame(local))
	var origin := local.global_position
	var point: Vector3 = info.point
	var dir: Vector3 = info.direction
	var key := "%s/%d/%.2f/%.2f/%.2f/%.2f/%.2f/%.2f/%s" % [local.data.id, slot, origin.x, origin.z, point.x, point.z, dir.x, dir.z, str(source.touch_skill_cancelled)]
	visible = true
	if key == _signature:
		return
	_signature = key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var color: Color = info.color.lerp(Color.WHITE, 0.25)
	if source.touch_skill_cancelled:
		color = Color("ef4444")
	color.a = host.tuning.skill_preview_outline_alpha
	var fill := Color(color.r, color.g, color.b, host.tuning.skill_preview_fill_alpha)
	var width := host.tuning.skill_preview_line_width
	match str(info.mode):
		"point":
			Vfx.ground_ring(self, origin, float(info.range), Color(color.r, color.g, color.b, 0.25), width)
			var landing := Vfx.ground_ring(self, point, float(info.radius), color, width * 2.0, fill.a)
			landing.name = "LandingArea"
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
					_line(previous, next, width, color)
				previous = next
		"cone":
			_shape(Vfx.fan_mesh(float(info.distance), float(info.angle), fill), origin, dir)
			_shape(Vfx.fan_border(float(info.distance), float(info.angle), color, width), origin, dir)
		"line", "lane", "path":
			var length: float = info.distance
			if length > width * 2.0:
				_shape(Vfx.lane_mesh(length, float(info.width), fill), origin, dir)
				_shape(Vfx.tag_strip_border(length, float(info.width) * 0.5, width, color), origin, dir)
				_shape(Vfx.arrow_mesh(length, width, width * 6.0, width * 4.0, color), origin, dir)
			if info.icon == "hand":
				Vfx.ground_ring(self, point, float(info.radius), color, width)
		"self":
			pass # a self buff gets an overhead cue, not a fake ground area

func _shape(mesh: MeshInstance3D, origin: Vector3, dir: Vector3) -> void:
	add_child(mesh)
	mesh.global_position = origin + Vector3.UP * 0.075
	mesh.rotation.y = atan2(dir.x, dir.z)

func _line(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	if from.distance_to(to) < 0.001:
		return
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, from.distance_to(to))
	line.mesh = mesh
	line.material_override = Vfx.flat_material(color)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	line.global_position = (from + to) * 0.5 + Vector3.UP * 0.08
	line.look_at(to + Vector3.UP * 0.08, Vector3.RIGHT if absf((to - from).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
