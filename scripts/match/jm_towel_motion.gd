extends Node3D

## Loosely rolled terry towel. Presentation-only constrained strand with body contacts.
var hero: Hero
var asset: Node3D
var skeleton: Skeleton3D
var points: Array[Vector3] = []
var rest: Array[Transform3D] = []
var age := 0.0
var previous: Array[Vector3] = []
var last_grip := Vector3.INF
var _solver_remainder := 0.0
var _initialized := false
var _settling := false
var _limb_capsules: Array = []

func setup(value: Hero) -> void:
	hero = value
	name = "ShoulderTowel"
	asset = preload("res://assets/props/jm_towel.glb").instantiate()
	add_child(asset)
	skeleton = asset.find_children("*", "Skeleton3D", true, false)[0]
	for node in asset.find_children("*", "AnimationPlayer", true, false):
		node.stop()
	for node in asset.find_children("*", "MeshInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(skeleton.get_bone_count()):
		rest.append(skeleton.get_bone_global_rest(i))
		points.append(Vector3.ZERO)

func _process(delta: float) -> void:
	if hero == null or hero.host.paused:
		return
	visible = hero.visual._alpha > 0.01
	age += delta
	if not hero.visual._bone_world_transforms.has(hero.visual._bone_by_tail("RightHand")):
		return
	_solver_remainder += minf(delta, 0.1)
	var step := 1.0 / RB.TICK_RATE
	while _solver_remainder >= step:
		_solver_remainder -= step
		_update_cloth(step)

## Verlet strand with fixed grip, distance constraints and capsule body contacts.
func body_project(point: Vector3) -> Vector3:
	var visual := hero.visual
	var hips := visual._bone_pos(visual._bone_by_tail("Hips"))
	var chest := visual._bone_pos(visual._bone_by_tail("Spine2"))
	var segment := chest - hips
	var t := clampf((point - hips).dot(segment) / maxf(0.001, segment.length_squared()), 0.0, 1.0)
	var center := hips + segment * t
	var offset := point - center
	var radius := hero.data.model_height * float(hero.data.v("towel_body_radius")) + float(hero.data.v("towel_clearance"))
	if offset.length() < radius:
		if offset.length_squared() < 0.00001:
			offset = visual.model.global_basis.z
		point = center + offset.normalized() * radius
	var head := visual._bone_pos(visual._bone_by_tail("Head")) - Vector3.UP * 0.08
	var head_offset := point - head
	var head_radius := hero.data.model_height * 0.17
	if head_offset.length() < head_radius and head_offset.length_squared() > 0.00001:
		point = head + head_offset.normalized() * head_radius
	for capsule in _limb_capsules:
		point = _capsule_project(point, capsule[0], capsule[1], capsule[2])
	point.y = maxf(hero.global_position.y + 0.05, point.y)
	return point

func _capsule_project(point: Vector3, a: Vector3, b: Vector3, radius: float) -> Vector3:
	var axis := b - a
	var along := clampf((point - a).dot(axis) / maxf(0.00001, axis.length_squared()), 0.0, 1.0)
	var center := a + axis * along
	var offset := point - center
	if offset.length_squared() > 0.00001 and offset.length() < radius:
		return center + offset.normalized() * radius
	return point

func _collect_limb_capsules() -> void:
	_limb_capsules.clear()
	for side in ["Left", "Right"]:
		for segment in [["UpLeg", "Leg", 0.16], ["Leg", "Foot", 0.125], ["Arm", "ForeArm", 0.12], ["ForeArm", "Hand", 0.105]]:
			_limb_capsules.append([hero.visual.bone_world(side + segment[0]), hero.visual.bone_world(side + segment[1]), segment[2]])

func _update_cloth(delta: float, reset := false) -> void:
	var visual := hero.visual
	_collect_limb_capsules()
	var forward := visual.model.global_basis.z.normalized()
	var right := -visual.model.global_basis.x.normalized()
	var grip := visual.bone_world_transform("RightHand") * Vector3(hero.data.v("towel_grip_offset"))
	reset = reset or not _initialized or last_grip == Vector3.INF or last_grip.distance_to(grip) > 0.8
	last_grip = grip
	var length_m := float(hero.data.v("towel_length"))
	var link := length_m / (points.size() - 1)
	var dt := delta
	var elapsed := visual.tag_elapsed()
	var strike := exp(-pow((elapsed - hero.tuning.tag_windup) / 0.065, 2.0)) if visual.tag_pose_active() and not _settling else 0.0
	var whipping := elapsed >= 0.0 and elapsed <= hero.tuning.tag_windup + hero.tuning.tag_followthrough + hero.tuning.failed_tag_stumble and hero.is_free()
	var direction := (Vector3.DOWN + forward * 0.3 + right * 0.3).normalized()
	if reset:
		_initialized = true
		previous.clear()
		for i in range(points.size()):
			points[i] = body_project(grip + direction * link * i) if i > 0 else grip
			previous.append(points[i])
		# Settle at the first rendered grip, not the uninitialized import pose. The
		# fixed substeps also remove render-rate-dependent Verlet velocity explosions.
		_settling = true
		for i in range(45):
			_update_cloth(1.0 / RB.TICK_RATE)
		_settling = false
		return
	points[0] = grip
	previous[0] = grip
	for i in range(1, points.size()):
		var current := points[i]
		var t := float(i) / (points.size() - 1)
		var velocity := (current - previous[i]) * exp(-dt * float(hero.data.v("towel_damping")))
		var target := grip + direction * (length_m * t)
		var acceleration := Vector3.DOWN * 9.8 + (target - current) * float(hero.data.v("towel_stiffness"))
		# Shoulder/wrist acceleration travels down the strand rather than rotating it rigidly.
		acceleration += hero.lunge_dir * strike * float(hero.data.v("towel_whip_force")) * (1.0 - t * 0.65)
		points[i] += velocity + acceleration * dt * dt
		previous[i] = current
	for iteration in range(int(hero.data.v("towel_iterations"))):
		points[0] = grip
		for i in range(1, points.size()):
			var offset := points[i] - points[i - 1]
			var distance := offset.length()
			if distance > 0.00001:
				var correction := offset * (1.0 - link / distance)
				if i == 1:
					points[i] -= correction
				else:
					points[i] -= correction * 0.5
					points[i - 1] += correction * 0.5
			points[i] = body_project(points[i])
			if not whipping or _settling:
				points[i].y = minf(points[i].y, grip.y - length_m * float(i) / (points.size() - 1) * 0.25)
	var inverse := skeleton.global_transform.affine_inverse()
	for i in range(points.size()):
		var a := points[maxi(0, i - 1)]
		var b := points[mini(points.size() - 1, i + 1)]
		var tangent := (inverse.basis * (b - a)).normalized()
		if tangent.length_squared() < 0.01:
			continue
		var turn := Quaternion(rest[i].basis.y.normalized(), tangent)
		skeleton.set_bone_global_pose(i, Transform3D(Basis(turn) * rest[i].basis, inverse * points[i]))
