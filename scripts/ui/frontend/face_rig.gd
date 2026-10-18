class_name FaceRig
extends RefCounted

## Painted mouth and eyelid cards on one hero's head (tools/build_face_cards.py): the hero meshes
## have no face rig, so the Home diorama lays three curved alpha cards over the face (a mouth and
## two lids) that show one flipbook frame at a time. attach() parents them to a BoneAttachment3D
## on mixamorig:Head; tick(t) picks the frames from the loop time, so a given t always gives the
## same face (blinks and mouth shapes come from a seeded RNG, never from wall-clock).

const DIR := "res://assets/characters/face_cards/"
const HEAD_BONE := "mixamorig_Head" ## Godot's import renames Mixamo's "mixamorig:Head"
const SHADER := "res://shaders/face_flipbook.gdshader"
const CARDS := ["Mouth", "Eye_R", "Eye_L"]

enum Mode { CLOSED, TALK, LAUGH, SMILE }

var hero_id := ""
var data: HomeDioramaData
var attachment: BoneAttachment3D
var mouth: MeshInstance3D
var eye_r: MeshInstance3D
var eye_l: MeshInstance3D
var mode := Mode.CLOSED
var talk_start := 0.0 ## loop time the current mode began (the mouth pattern is relative to it)
var _blinks: Array[float] = [] ## blink start times across one loop
var _mouth_mat: ShaderMaterial
var _lid_mat: ShaderMaterial
var _seed := 1

## Builds the cards on `model` (a hero scene already in the tree, normalised). False when the
## hero has no cards or no head bone.
func attach(p_hero_id: String, model: Node3D, p_data: HomeDioramaData) -> bool:
	hero_id = p_hero_id
	data = p_data
	_seed = int(data.face_seeds.get(hero_id, 1))
	var skel: Skeleton3D = null
	for n in model.find_children("*", "Skeleton3D", true, false):
		skel = n
		break
	var path := DIR + hero_id + "_cards.glb"
	if skel == null or not ResourceLoader.exists(path):
		return false
	var bone := skel.find_bone(HEAD_BONE)
	if bone < 0:
		return false
	var cards := (load(path) as PackedScene).instantiate() as Node3D
	model.add_child(cards) ## identity: the cards are authored in the model's rest space
	_build_materials()
	attachment = BoneAttachment3D.new()
	attachment.name = "FaceCards"
	attachment.bone_name = HEAD_BONE
	skel.add_child(attachment)
	var rest_inv := skel.get_bone_global_rest(bone).affine_inverse()
	for card_name in CARDS:
		var found := cards.find_child(card_name, true, false) as MeshInstance3D
		if found == null:
			continue
		var in_skel := skel.global_transform.affine_inverse() * found.global_transform
		found.get_parent().remove_child(found)
		attachment.add_child(found)
		found.transform = rest_inv * in_skel
		found.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		found.material_override = _mouth_mat if card_name == "Mouth" else _lid_mat
		match card_name:
			"Mouth": mouth = found
			"Eye_R": eye_r = found
			"Eye_L": eye_l = found
	cards.queue_free()
	_plan_blinks()
	set_frames(data.mouth_closed, data.lid_open)
	return mouth != null and eye_r != null and eye_l != null

func _build_materials() -> void:
	var shader := load(SHADER) as Shader
	_mouth_mat = ShaderMaterial.new()
	_mouth_mat.shader = shader
	_mouth_mat.set_shader_parameter("atlas", load(DIR + hero_id + "_mouth.png"))
	_mouth_mat.set_shader_parameter("atlas_cols", data.mouth_atlas_cols)
	_mouth_mat.set_shader_parameter("atlas_rows", data.mouth_atlas_rows)
	_mouth_mat.set_shader_parameter("depth_bias", data.face_depth_bias)
	_lid_mat = ShaderMaterial.new()
	_lid_mat.shader = shader
	_lid_mat.set_shader_parameter("atlas", load(DIR + hero_id + "_lids.png"))
	_lid_mat.set_shader_parameter("atlas_cols", data.lid_atlas_cols)
	_lid_mat.set_shader_parameter("atlas_rows", data.lid_atlas_rows)
	_lid_mat.set_shader_parameter("depth_bias", data.face_depth_bias)

## One loop's worth of blink start times from the hero's seed (the same every loop).
func _plan_blinks() -> void:
	_blinks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var t := rng.randf_range(data.blink_min, data.blink_max) * 0.5
	while t + data.blink_duration < data.loop_length:
		_blinks.append(t)
		t += rng.randf_range(data.blink_min, data.blink_max)

func set_mode(p_mode: Mode, t: float) -> void:
	if p_mode != mode:
		mode = p_mode
		talk_start = t

func set_frames(mouth_frame: int, lid_frame: int) -> void:
	if _mouth_mat:
		_mouth_mat.set_shader_parameter("frame", mouth_frame)
	if _lid_mat:
		_lid_mat.set_shader_parameter("frame", lid_frame)

## The lid frame at loop time t: a blink is open, half, closed, half; a laugh keeps the eyes shut.
func lid_frame_at(t: float) -> int:
	if mode == Mode.LAUGH:
		return data.lid_closed
	for b in _blinks:
		if t >= b and t < b + data.blink_duration:
			var p := (t - b) / data.blink_duration
			return data.lid_half if (p < 0.25 or p >= 0.75) else data.lid_closed
	return data.lid_open

## The mouth frame at loop time t for the current mode.
func mouth_frame_at(t: float) -> int:
	match mode:
		Mode.TALK:
			var step := int(floor(maxf(t - talk_start, 0.0) * data.mouth_rate))
			var rng := RandomNumberGenerator.new()
			rng.seed = _seed * 7919 + step
			var r := rng.randf()
			if r < data.mouth_pick_closed:
				return data.mouth_closed
			r -= data.mouth_pick_closed
			if r < data.mouth_pick_small:
				return data.mouth_small
			r -= data.mouth_pick_small
			if r < data.mouth_pick_wide:
				return data.mouth_wide
			r -= data.mouth_pick_wide
			return data.mouth_o if r < data.mouth_pick_o else data.mouth_smile
		Mode.LAUGH:
			var k := int(floor(maxf(t - talk_start, 0.0) * data.laugh_rate))
			return data.mouth_laugh if k % 2 == 0 else data.mouth_wide
		Mode.SMILE:
			return data.mouth_smile
	return data.mouth_closed

func tick(t: float) -> void:
	set_frames(mouth_frame_at(t), lid_frame_at(t))
