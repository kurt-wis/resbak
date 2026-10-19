extends SkillObject

var direction := Vector3.FORWARD
var length_m := 0.0
var width_m := 0.0
var bonus := 0.0
var slow := 0.0
var form_ticks := 1
var age_ticks := 0
var surface: MeshInstance3D
var streaks: CPUParticles3D
var ribbons: Array[MeshInstance3D] = []
var _affected: Array[Hero] = []
var _source := ""

func _ready() -> void:
	name = "IhipLane"
	_source = "ihip_%d" % get_instance_id()
	rotation.y = atan2(direction.x, direction.z)
	surface = Vfx.lane_mesh(length_m, width_m, Color(0.5, 0.87, 1.0, 0.17))
	surface.position.y = 0.07
	add_child(surface)
	streaks = Vfx.emitter(self, Color(0.9, 1, 1, 0.7), 42, 0.65, 0.12, length_m / 0.65, Vector3(0, 0.5, 0), false)
	streaks.direction = Vector3(0, 0, 1)
	streaks.spread = 3.0
	streaks.gravity = Vector3.ZERO
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	streaks.emission_box_extents = Vector3(width_m * 0.5, 0.3, 0.1)
	streaks.emitting = true
	for i in range(3):
		var points := PackedVector3Array()
		for j in range(33):
			var t := float(j) / 32.0
			points.append(Vector3((i - 1) * width_m * 0.28 + sin(t * TAU * 2.0 + i) * 0.12, 0.14 + sin(t * PI) * 0.16, t * length_m))
		var ribbon := Vfx.ribbon(points, 0.035, Color(0.76, 0.96, 1.0, 0.55))
		add_child(ribbon)
		ribbons.append(ribbon)
	_update_growth()

func formed_fraction() -> float:
	return clampf(float(age_ticks) / maxi(1, form_ticks), 0.0, 1.0)

func formed_length() -> float:
	return length_m * formed_fraction()

func _update_growth() -> void:
	var fraction := formed_fraction()
	surface.visible = fraction > 0.0
	surface.scale.z = maxf(0.001, fraction)
	for ribbon in ribbons:
		ribbon.visible = surface.visible
		ribbon.scale.z = surface.scale.z
	streaks.position.z = formed_length()
	streaks.initial_velocity_min = 0.2
	streaks.initial_velocity_max = 0.8

func contains(point: Vector3) -> bool:
	if expired or absf(point.y - global_position.y) > host.tuning.height_gap:
		return false
	var rel := RB.flat(point - global_position)
	var along := rel.dot(direction)
	return along >= 0.0 and along <= formed_length() and absf(rel.x * direction.z - rel.z * direction.x) <= width_m * 0.5

func disadvantages(h: Hero) -> bool:
	return h.is_free() and (h == owner_hero or h.team != team) and contains(h.global_position)

func tick(dt: float) -> void:
	for h in _affected:
		if is_instance_valid(h):
			h.clear_modifier(_source)
	_affected.clear()
	super.tick(dt)
	if expired:
		return
	age_ticks += 1
	_update_growth()
	for h in host.heroes:
		if not h.is_free() or not contains(h.global_position):
			continue
		if disadvantages(h):
			h.add_slow(slow, 2.0 / RB.TICK_RATE, _source, false)
		else:
			h.add_speed_bonus(bonus, 2.0 / RB.TICK_RATE, _source)
		_affected.append(h)

func _on_expire() -> void:
	for h in _affected:
		if is_instance_valid(h):
			h.clear_modifier(_source)
	_affected.clear()
