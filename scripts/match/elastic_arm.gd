extends SkeletonModifier3D

## Post-animation deformation of Inday's own weighted arm; the palm is never duplicated.
var visual: HeroVisual
var upper := -1
var fore := -1
var hand := -1

func _ready() -> void:
	modification_processed.connect(_capture)

func _capture() -> void:
	if visual == null or not visual.hila_pose_active():
		return
	visual._on_skel_updated()

func _process_modification() -> void:
	if visual == null or not visual.hila_pose_active():
		return
	var sk := get_skeleton()
	if upper < 0 or fore < 0 or hand < 0:
		return
	var a := sk.get_bone_global_pose(upper)
	var b := sk.get_bone_global_pose(fore)
	var c := sk.get_bone_global_pose(hand)
	var target := sk.global_transform.affine_inverse() * visual.hila_visual_target()
	var delta := target - a.origin
	var length := delta.length()
	var natural := a.origin.distance_to(b.origin) + b.origin.distance_to(c.origin)
	if length < 0.001 or natural < 0.001:
		return
	var dir := delta / length
	var ratio := maxf(1.0, length / natural)
	# A common orthogonal axis avoids sheared local poses, which Skeleton3D must
	# decompose into rotation/scale. Only local Y stretches; the hand cancels it.
	var x := a.basis.x.slide(dir).normalized()
	if x.length_squared() < 0.01:
		x = Vector3.RIGHT.slide(dir).normalized()
	var z := x.cross(dir).normalized()
	x = dir.cross(z).normalized()
	var aligned := Basis(x, dir, z)
	a.basis = Basis(x, dir * ratio, z)
	b.basis = a.basis
	b.origin = a.origin + dir * a.origin.distance_to(sk.get_bone_global_pose(fore).origin) * ratio
	c.origin = target
	c.basis = aligned
	# Build local poses against the desired parent transforms, avoiding stale global caches
	# while a nonuniformly stretched parent is being changed in the same modifier pass.
	var desired := {upper: a, fore: b, hand: c}
	for index in [upper, fore, hand]:
		var parent := sk.get_bone_parent(index)
		var parent_pose: Transform3D = desired.get(parent, sk.get_bone_global_pose(parent))
		sk.set_bone_pose(index, parent_pose.affine_inverse() * desired[index])
	sk.force_update_all_bone_transforms()
	var actual := sk.global_transform * sk.get_bone_global_pose(hand).origin
	set_meta("hand_world", actual)
	set_meta("target_error", actual.distance_to(visual.hila_visual_target()))
	visual._bones_world[sk.get_bone_name(upper)] = sk.global_transform * a.origin
	visual._bones_world[sk.get_bone_name(fore)] = sk.global_transform * b.origin
	visual._bones_world[sk.get_bone_name(hand)] = sk.global_transform * c.origin
