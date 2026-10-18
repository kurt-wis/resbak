extends SkillObject

var direction := Vector3.FORWARD
var length_m := 0.0
var width_m := 0.0
var bonus := 0.0
var slow := 0.0
var _affected: Array[Hero] = []
var _source := ""

func _ready() -> void:
	name = "IhipLane"
	_source = "ihip_%d" % get_instance_id()
	rotation.y = atan2(direction.x, direction.z)
	var lane := Vfx.lane_mesh(length_m, width_m, Color(0.5, 0.87, 1.0, 0.17))
	lane.position.y = 0.07
	add_child(lane)
	var streaks := Vfx.emitter(self, Color(0.9, 1, 1, 0.7), 42, 0.65, 0.12, length_m / 0.65, Vector3(0, 0.5, 0), false)
	streaks.direction = Vector3(0, 0, 1)
	streaks.spread = 3.0
	streaks.gravity = Vector3.ZERO
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	streaks.emission_box_extents = Vector3(width_m * 0.5, 0.3, 0.1)
	streaks.emitting = true

func contains(point: Vector3) -> bool:
	if expired or absf(point.y - global_position.y) > host.tuning.height_gap:
		return false
	var rel := RB.flat(point - global_position)
	var along := rel.dot(direction)
	return along >= 0.0 and along <= length_m and absf(rel.x * direction.z - rel.z * direction.x) <= width_m * 0.5

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
