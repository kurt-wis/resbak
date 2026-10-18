extends SkeletonModifier3D

## Presentation only: feet follow travel during an upper-body action, while the spine keeps
## the committed action heading. Installed before arm IK; no host positions are changed.
var heading_delta := 0.0
var hips := -1
var spine := -1

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or hips < 0 or spine < 0 or absf(heading_delta) < 0.001:
		return
	var torso := skeleton.get_bone_global_pose(spine).basis
	var pelvis := skeleton.get_bone_global_pose(hips)
	pelvis.basis = Basis(Vector3.UP, heading_delta) * pelvis.basis
	skeleton.set_bone_global_pose(hips, pelvis)
	var upper := skeleton.get_bone_global_pose(spine)
	upper.basis = torso
	skeleton.set_bone_global_pose(spine, upper)
