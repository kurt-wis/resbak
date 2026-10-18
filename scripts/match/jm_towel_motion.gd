extends Node3D

## Soft shoulder cloth. Only presentation: no collision layers, input or host state.
## A double-sided skinned sheet follows hand/shoulder anchors, with damped free ends.
var hero: Hero
var asset: Node3D
var skeleton: Skeleton3D
var points: Array[Vector3] = []
var rest: Array[Transform3D] = []
var age := 0.0
var attack_blend := 0.0

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
	_update_cloth(0.0, true)

func _process(delta: float) -> void:
	if hero == null or hero.host.paused:
		return
	visible = hero.visual._alpha > 0.01
	age += delta
	_update_cloth(minf(delta, 0.05))

func _curve(t: float, controls: Array[Vector3]) -> Vector3:
	var u := t * 3.0
	var k := mini(2, floori(u))
	var f := u - k
	var a := controls[maxi(0, k - 1)]
	var b := controls[k]
	var c := controls[k + 1]
	var d := controls[mini(3, k + 2)]
	return 0.5 * (2.0 * b + (-a + c) * f + (2.0 * a - 5.0 * b + 4.0 * c - d) * f * f + (-a + 3.0 * b - 3.0 * c + d) * f * f * f)

func _update_cloth(delta: float, reset := false) -> void:
	var visual := hero.visual
	var forward := visual.model.global_basis.z.normalized()
	var right := -visual.model.global_basis.x.normalized()
	var up := Vector3.UP
	var shoulder := visual._bone_pos(visual._bone_by_tail("RightArm")) + up * 0.065
	var grip := visual.hand_position(0) + forward * 0.025
	var controls: Array[Vector3] = [grip, shoulder + forward * 0.025, shoulder - forward * 0.17 - up * 0.055, shoulder - forward * 0.23 - up * 0.48]
	var attacking := visual.tag_pose_active() or hero.frame.tag_preparing and hero.can_press_tag()
	attack_blend = move_toward(attack_blend, 1.0 if attacking else 0.0, delta * 12.0)
	var tension := visual._tag_weight()
	var swing := Vector3.DOWN.lerp(hero.lunge_dir, tension).normalized()
	var inverse := skeleton.global_transform.affine_inverse()
	for i in range(points.size()):
		var t := float(i) / (points.size() - 1)
		var carry := _curve(t, controls)
		# The shoulder arch stays pinned; the lower back end responds to running.
		var free_end := smoothstep(0.48, 1.0, t)
		carry -= RB.flat(hero.velocity) * 0.018 * free_end
		carry += right * sin(age * 7.0 - t * 5.0) * 0.018 * free_end
		carry += forward * sin(t * PI * 2.4 + age * 2.0) * 0.025 * free_end
		var whip := grip + swing * (t * 0.85) + right * sin(t * PI) * sin(age * 13.0 - t * 5.0) * 0.065
		var target := carry.lerp(whip, attack_blend)
		points[i] = target if reset or i == 0 else points[i].lerp(target, 1.0 - exp(-delta * lerpf(45.0, 22.0, free_end)))
	for i in range(points.size()):
		var a := points[maxi(0, i - 1)]
		var b := points[mini(points.size() - 1, i + 1)]
		var tangent := (inverse.basis * (b - a)).normalized()
		if tangent.length_squared() < 0.01:
			continue
		var turn := Quaternion(rest[i].basis.y.normalized(), tangent)
		var t := float(i) / (points.size() - 1)
		var twist := Quaternion(tangent, sin(t * PI * 2.0 + age * 2.5) * 0.12 * smoothstep(0.3, 1.0, t))
		skeleton.set_bone_global_pose(i, Transform3D(Basis(twist * turn) * rest[i].basis, inverse * points[i]))
