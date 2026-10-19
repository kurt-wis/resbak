extends SkeletonModifier3D

## Head-owned braid simulation. World-space inertia and body contact are cosmetic only.
var visual: HeroVisual
var bones: Array[int] = []
var offsets: Array[Transform3D] = []
var points: Array[Vector3] = []
var velocities: Array[Vector3] = []
var head := -1
var last_root := Vector3.INF

func _ready() -> void:
	var sk := get_skeleton()
	head = sk.find_bone(visual._bone_by_tail("Head"))
	for i in range(4):
		var bone := sk.find_bone("mixamorig_Hair%d" % (i + 1))
		if bone < 0:
			continue
		bones.append(bone)
		offsets.append(sk.get_bone_global_rest(head).affine_inverse() * sk.get_bone_global_rest(bone))
		points.append(Vector3.ZERO)
		velocities.append(Vector3.ZERO)

func body_project(point: Vector3) -> Vector3:
	var front := visual.model.global_basis.z.normalized()
	var local := visual.model.to_local(point)
	# A conservative back-of-blouse plane in model space, bounded to the torso.
	var height := visual.hero.data.model_height
	if point.y < visual.hero.global_position.y + height * 0.76 and absf(local.x) < 0.38:
		var chest := visual._bone_pos(visual._bone_by_tail("Spine2"))
		var depth := (point - chest).dot(-front)
		var clearance := height * float(visual.hero.data.v("hair_back_clearance"))
		if depth < clearance:
			point -= front * (clearance - depth)
	return point

func _process_modification() -> void:
	if visual == null or visual.hero.host.paused or head < 0:
		return
	var sk := get_skeleton()
	var head_pose := sk.get_bone_global_pose(head)
	var root := sk.global_transform * (head_pose * offsets[0]).origin if not bones.is_empty() else Vector3.ZERO
	var dt := minf(get_process_delta_time(), 1.0 / 30.0)
	var reset := last_root == Vector3.INF or root.distance_to(last_root) > 0.8
	for i in range(bones.size()):
		var pose := head_pose * offsets[i]
		var target := sk.global_transform * pose.origin
		if reset:
			points[i] = body_project(target)
			velocities[i] = Vector3.ZERO
		var force := (target - points[i]) * float(visual.hero.data.v("hair_stiffness")) - velocities[i] * float(visual.hero.data.v("hair_damping"))
		velocities[i] += force * dt
		points[i] = body_project(points[i] + velocities[i] * dt)
		# Keep simulation bounded even after teleports or severe animation changes.
		points[i] = target + (points[i] - target).limit_length(float(visual.hero.data.v("hair_max_offset")))
		points[i] = body_project(points[i])
		pose.origin = sk.global_transform.affine_inverse() * points[i]
		sk.set_bone_global_pose(bones[i], pose)
	last_root = root
