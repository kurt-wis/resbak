class_name DioramaActor
extends Node3D

## One performer in the Home diorama: a hero (Mixamo rig, AnimationTree with a looping base idle
## plus upper-body and full-body gesture one-shots, painted face cards, head look-at) or a
## bystander (Meshy rig, one looping clip seeked from the loop time). Presentation only.
## Hero poses come from stepping the tree, everything else is a pure function of the loop time.

const PROP_DIR := "res://assets/props/home/"
const HEAD_BONE := "mixamorig_Head"
const UPPER_ROOT := "mixamorig_Spine"
const TOON := "res://shaders/character_toon.gdshader"
const OUTLINE := "res://shaders/character_outline.gdshader"
const OUTLINE_PX := 2.0 ## Home set-piece compatibility; characters use Tuning.character_outline_pixels

var id := ""
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var tree: AnimationTree
var face: FaceRig
var look: LookAtModifier3D
var look_marker: Marker3D
var props: Array[Node3D] = []
var data: HomeDioramaData
var head_bone := -1
var full_active := false
var _look_pos := Vector3.ZERO
var _look_goal := Vector3.ZERO
var _look_weight := 1.0
var _clip := ""
var _clip_len := 1.0
var _cycles := 0

## Flat toon materials on every opaque surface under `root` (the project's character look), with
## the ink outline when `outline` is set. Transparent materials (bags, glass) are left alone.
static func toonify(root: Node, outline: bool) -> void:
	var toon := load(TOON) as Shader
	var ink: ShaderMaterial = null
	if outline:
		ink = ShaderMaterial.new()
		ink.shader = load(OUTLINE)
		ink.set_shader_parameter("outline_pixels", (load(Tuning.PATH) as Tuning).character_outline_pixels)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(s)
			if src is not StandardMaterial3D:
				continue
			var sm := src as StandardMaterial3D
			if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var m := ShaderMaterial.new()
			m.shader = toon
			m.set_shader_parameter("base_texture", sm.albedo_texture)
			m.set_shader_parameter("base_color", sm.albedo_color)
			if ink:
				m.next_pass = ink
			mi.set_surface_override_material(s, m)

# ---- heroes ---------------------------------------------------------------------------------
## Builds a hero here. The actor must already be in the tree (the model is normalised from its
## global bounds). `entry` is HomeDioramaData.cast[hero_id].
func build_hero(hero_id: String, p_data: HomeDioramaData, entry: Dictionary) -> bool:
	id = hero_id
	data = p_data
	var hd := HeroData.load_hero(hero_id)
	if hd == null:
		return false
	model = (load(hd.glb) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	Portraits._normalise(model, hd.model_height)
	Portraits._toon(model)
	_find_rig()
	if animator == null or skeleton == null:
		return false
	head_bone = skeleton.find_bone(HEAD_BONE)
	var base: String = entry.get("base", "Menu_StandIdle")
	for clip in animator.get_animation_list():
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip == base else Animation.LOOP_NONE
	# The base clip is the hero's own idle: the seat fit reads its first frame, and the QC tools and
	# the loop edge both measure poses against it, so it is worth the two book-keeping fields.
	_clip = base
	if animator.has_animation(base):
		_clip_len = animator.get_animation(base).length
	_build_tree(base, int(entry.get("cycles", 1)))
	face = FaceRig.new()
	face.attach(hero_id, model, data)
	_build_look()
	attach_prop(entry.get("prop", {}))
	return true

func _find_rig() -> void:
	for n in model.find_children("*", "AnimationPlayer", true, false):
		animator = n
		break
	for n in model.find_children("*", "Skeleton3D", true, false):
		skeleton = n
		break

## Base idle (stretched so a whole number of cycles fits the loop) under an upper-body one-shot
## (spine, arms, head: gestures leave the seated or standing legs alone) under a full-body one-shot.
func _build_tree(base_clip: String, cycles: int) -> void:
	var bt := AnimationNodeBlendTree.new()
	var base := AnimationNodeAnimation.new()
	base.animation = base_clip
	if cycles > 0:
		base.use_custom_timeline = true
		base.timeline_length = data.loop_length / float(cycles)
		base.stretch_time_scale = true
		base.loop_mode = Animation.LOOP_LINEAR
	bt.add_node("Base", base, Vector2(0, 0))
	for shot in ["Upper", "Full"]:
		var g := AnimationNodeAnimation.new()
		g.animation = base_clip
		bt.add_node("Gesture" + shot, g, Vector2(0, 200 if shot == "Upper" else 400))
		var one := AnimationNodeOneShot.new()
		one.fadein_time = data.gesture_fade_in
		one.fadeout_time = data.gesture_fade_out
		if data.gesture_fade_smooth:
			# Ease-in-out instead of the default linear ramp: a linear blend changes the hand's
			# velocity in one frame when the fade starts and again when it ends.
			one.fadein_curve = _smooth_curve()
			one.fadeout_curve = _smooth_curve()
		if shot == "Upper":
			one.filter_enabled = true
			for path in _upper_paths():
				one.set_filter_path(path, true)
		bt.add_node(shot, one, Vector2(300, 0 if shot == "Upper" else 200))
	bt.connect_node("Upper", 0, "Base")
	bt.connect_node("Upper", 1, "GestureUpper")
	bt.connect_node("Full", 0, "Upper")
	bt.connect_node("Full", 1, "GestureFull")
	bt.connect_node("output", 0, "Full")
	tree = AnimationTree.new()
	tree.name = "DioramaTree"
	tree.tree_root = bt
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.add_sibling(tree)
	tree.anim_player = tree.get_path_to(animator)
	tree.active = true

## Smoothstep as a Curve: 0 -> 1 with flat tangents at both ends.
static func _smooth_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0), 0.0, 0.0)
	c.add_point(Vector2(1, 1), 0.0, 0.0)
	return c

## The Spine bone and everything below it, as filter paths relative to the model root.
func _upper_paths() -> Array[NodePath]:
	var out: Array[NodePath] = []
	var root_bone := skeleton.find_bone(UPPER_ROOT)
	var skel_path := model.get_path_to(skeleton)
	for b in range(skeleton.get_bone_count()):
		var p := b
		while p >= 0 and p != root_bone:
			p = skeleton.get_bone_parent(p)
		if p == root_bone and root_bone >= 0:
			out.append(NodePath("%s:%s" % [skel_path, skeleton.get_bone_name(b)]))
	return out

func _build_look() -> void:
	look_marker = Marker3D.new()
	look_marker.name = "GazeTarget"
	look_marker.top_level = true
	add_child(look_marker)
	look = LookAtModifier3D.new()
	look.name = "HeadLook"
	skeleton.add_child(look)
	look.bone_name = HEAD_BONE
	look.target_node = look.get_path_to(look_marker)
	_aim_look_axes()
	look.use_angle_limitation = true
	look.symmetry_limitation = true
	look.primary_limit_angle = deg_to_rad(data.look_yaw_limit)
	look.secondary_limit_angle = deg_to_rad(data.look_pitch_limit)
	_look_goal = data.look_default
	_look_pos = _look_goal
	look_marker.global_position = _look_pos

## The head bone's local axes differ per rig (Mixamo bones point along their length), so pick the
## bone axis that points where the model faces in the rest pose (forward) and the one that points up
## (the yaw axis), instead of assuming +Z / +Y.
func _aim_look_axes() -> void:
	var rest := skeleton.global_transform.basis * skeleton.get_bone_global_rest(head_bone).basis
	var model_basis := model.global_transform.basis
	var fwd_world := model_basis.z.normalized()
	var up_world := model_basis.y.normalized()
	var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var enums := [SkeletonModifier3D.BONE_AXIS_PLUS_X, SkeletonModifier3D.BONE_AXIS_MINUS_X,
			SkeletonModifier3D.BONE_AXIS_PLUS_Y, SkeletonModifier3D.BONE_AXIS_MINUS_Y,
			SkeletonModifier3D.BONE_AXIS_PLUS_Z, SkeletonModifier3D.BONE_AXIS_MINUS_Z]
	var best := -2.0
	var best_i := 4
	for i in range(axes.size()):
		var d: float = (rest * (axes[i] as Vector3)).normalized().dot(fwd_world)
		if d > best:
			best = d
			best_i = i
	look.forward_axis = enums[best_i]
	var best_up := -2.0
	var up_axis := Vector3.AXIS_Y
	for i in range(3):
		var local_axis: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][i]
		var d: float = absf((rest * local_axis).normalized().dot(up_world))
		if i != best_i / 2 and d > best_up:
			best_up = d
			up_axis = [Vector3.AXIS_X, Vector3.AXIS_Y, Vector3.AXIS_Z][i]
	look.primary_rotation_axis = up_axis

# ---- bystanders -----------------------------------------------------------------------------
func build_bystander(who: String, p_data: HomeDioramaData, entry: Dictionary) -> bool:
	id = who
	data = p_data
	model = (load("res://assets/characters/bystanders/%s.glb" % who) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * data.bystander_height_fix
	add_child(model)
	_find_rig()
	if animator == null or skeleton == null:
		return false
	_clip = entry.get("clip", "Walk")
	if not animator.has_animation(_clip):
		return false
	_cycles = int(entry.get("cycles", 0))
	var anim := animator.get_animation(_clip)
	anim.loop_mode = Animation.LOOP_LINEAR
	_clip_len = anim.length
	animator.play(_clip)
	animator.pause()
	if data.bystander_toon:
		toonify(model, true)
	attach_prop(entry.get("prop", {}))
	return true

## Pose the looping clip at `u` seconds into it.
func seek_clip(u: float) -> void:
	animator.seek(fposmod(u, _clip_len), true)

## A stationary performer: `_cycles` whole clip cycles per loop, so the pose matches at the wrap.
func seek_loop(t: float) -> void:
	var period := data.loop_length / float(maxi(_cycles, 1))
	animator.seek(fposmod(t, period) / period * _clip_len, true)

# ---- shared ---------------------------------------------------------------------------------
## A prop held on a bone: grip at the prop's origin, offsets from data. The attachment inherits the
## rig's scale (Meshy's armature is 0.01), so the prop is scaled back to real metres.
func attach_prop(entry: Dictionary) -> Node3D:
	if entry.is_empty() or skeleton == null:
		return null
	var bone: String = entry.get("bone", "")
	if skeleton.find_bone(bone) < 0:
		push_warning("DioramaActor %s: no bone %s for prop" % [id, bone])
		return null
	var att := BoneAttachment3D.new()
	att.name = "Hold_" + String(entry.scene)
	att.bone_name = bone
	skeleton.add_child(att)
	var prop := (load(PROP_DIR + String(entry.scene) + ".tscn") as PackedScene).instantiate() as Node3D
	att.add_child(prop)
	toonify(prop, true)
	var s := att.global_transform.basis.get_scale()
	prop.scale = Vector3.ONE * float(entry.get("scale", 1.0)) / maxf(s.x, 0.0001)
	prop.position = entry.get("pos", Vector3.ZERO) / maxf(s.x, 0.0001)
	prop.rotation_degrees = entry.get("rot", Vector3.ZERO)
	props.append(prop)
	return prop

func request_gesture(clip: String, full_body := false) -> void:
	if tree == null or not animator.has_animation(clip):
		push_warning("DioramaActor %s: no clip %s" % [id, clip])
		return
	var shot := "Full" if full_body else "Upper"
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node("Gesture" + shot) as AnimationNodeAnimation
	node.animation = clip
	tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if full_body:
		full_active = true

func end_gesture(full_body := false) -> void:
	if tree == null:
		return
	var shot := "Full" if full_body else "Upper"
	tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	if full_body:
		full_active = false

## Drops any running gesture at once (a seek back to the start of the loop).
func abort_gestures() -> void:
	if tree == null:
		return
	for shot in ["Upper", "Full"]:
		tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	full_active = false

func set_gaze_goal(p: Vector3) -> void:
	_look_goal = p

## World position of the head bone (what the others look at).
func head_world() -> Vector3:
	if skeleton == null or head_bone < 0:
		return global_position + Vector3(0, 1.4, 0)
	return skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin

func step(delta: float, t: float) -> void:
	if tree:
		tree.advance(delta)
	if look:
		_look_pos = _look_pos.lerp(_look_goal, 1.0 - exp(-data.look_rate * delta))
		look_marker.global_position = _look_pos
		var want := 0.0 if full_active else 1.0
		_look_weight = lerpf(_look_weight, want, 1.0 - exp(-data.look_off_rate * delta))
		look.influence = _look_weight
	if face:
		face.tick(t)
