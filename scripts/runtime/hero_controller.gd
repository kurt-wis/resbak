class_name HeroController
extends CharacterBody3D

## Shared locomotion controller for the Meshy heroes (Tutoy, Nene, Nathan, JM, Inday).
## Idle / Walking / Running are blended by horizontal speed through an AnimationTree
## BlendSpace1D, so the pose changes smoothly as the hero speeds up and slows down.
## Movement rule (design doc, 2026-10-16): no sprint, no stamina. Heroes always run;
## a stick tilted 15-50 % walks at half run speed, under 15 % stands still. Keyboard runs.
## Skills are not implemented here yet.
## Same facing convention as BatangHamogController: only `visual` is yawed (atan2(x, z)).

const STICK_DEADZONE := 0.15
const STICK_RUN := 0.5
const WALK_FRACTION := 0.5

@export var hero_id: String = "tutoy"
@export var run_speed: float = 5.0 ## replaced by the roster's per-hero run_speed in _ready()
var walk_speed: float = 2.5
## Ground speed (m/s, game scale) each clip's planted foot pushes at, measured by
## tools/qc_asset.py and stored in the roster. Playback is scaled to match the real
## speed so the feet don't skate; 0 = unknown, play at 1x.
var walk_clip_speed: float = 0.0
var run_clip_speed: float = 0.0
@export var acceleration: float = 14.0
@export var deceleration: float = 18.0
@export var turn_speed: float = 15.0
@export var model_height: float = 1.8 ## matches Batang Hamog's on-screen size

const BLEND_PARAM := "parameters/Locomotion/blend_position"
const TIMESCALE_PARAM := "parameters/Speed/scale"

var visual: Node3D
var model: Node3D
var animator: AnimationPlayer
var anim_tree: AnimationTree
var body_collision: CollisionShape3D
var idle_clip: String = ""
var walk_clip: String = ""
var run_clip: String = ""
var external_move: Vector2 = Vector2.ZERO ## touch / test override, same scale as a stick

func _ready() -> void:
	_ensure_input_actions()
	floor_snap_length = 0.35
	floor_constant_speed = true
	body_collision = CollisionShape3D.new()
	body_collision.name = "BodyCollision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	body_collision.shape = cap
	body_collision.position.y = 0.8
	add_child(body_collision)
	_setup_model()
	_setup_anim_tree()

func _ensure_input_actions() -> void:
	# Movement actions come from project.godot (BatangHamogController adds them too if missing).
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)

func _setup_model() -> void:
	visual = Node3D.new()
	visual.name = "CharacterVisual"
	add_child(visual)
	var hero := HeroRoster.get_hero(hero_id)
	assert(not hero.is_empty(), "Unknown hero id %s" % hero_id)
	run_speed = hero.get("run_speed", run_speed)
	walk_speed = run_speed * WALK_FRACTION
	walk_clip_speed = hero.get("walk_clip_speed", 0.0)
	run_clip_speed = hero.get("run_clip_speed", 0.0)
	var packed: PackedScene = load(hero["glb"]) as PackedScene
	model = packed.instantiate() as Node3D
	model.name = hero["name"].replace(" ", "")
	visual.add_child(model)
	# Normalize to model_height and stand on y = 0, same as BatangHamogController.
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	if found and bounds.size.y > 0.01:
		var factor: float = model_height / bounds.size.y
		model.scale = Vector3.ONE * factor
		model.position.y = -bounds.position.y * factor
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animator = node as AnimationPlayer
		break
	if animator == null:
		return
	for clip in animator.get_animation_list():
		var low := clip.to_lower()
		if low == "idle":
			idle_clip = clip
		elif low == "walking":
			walk_clip = clip
		elif low == "running":
			run_clip = clip
		else:
			continue
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func _setup_anim_tree() -> void:
	if animator == null or idle_clip == "" or walk_clip == "" or run_clip == "":
		push_warning("HeroController %s: missing Idle/Walking/Running clips" % hero_id)
		return
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = run_speed
	space.sync = true # keep walk and run feet in phase while blending
	for point in [[idle_clip, 0.0], [walk_clip, walk_speed], [run_clip, run_speed]]:
		var node := AnimationNodeAnimation.new()
		node.animation = point[0]
		space.add_blend_point(node, point[1], -1, point[0])
	var tree := AnimationNodeBlendTree.new()
	tree.add_node("Locomotion", space, Vector2(0, 0))
	tree.add_node("Speed", AnimationNodeTimeScale.new(), Vector2(240, 0))
	tree.connect_node("Speed", 0, "Locomotion")
	tree.connect_node("output", 0, "Speed")
	anim_tree = AnimationTree.new()
	anim_tree.name = "LocomotionTree"
	anim_tree.tree_root = tree
	animator.add_sibling(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(animator)
	anim_tree.set(TIMESCALE_PARAM, 1.0)
	anim_tree.active = true

func _read_move_input() -> Vector2:
	# Deadzone 0 = raw stick tilt, so the 15 % / 50 % thresholds below are exact.
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.0)
	if external_move.length() > 0.0:
		v = external_move
	return v.limit_length()

## Speed the stick tilt asks for: 0, walk_speed or run_speed. Keys always give full tilt.
func speed_for_tilt(tilt: float) -> float:
	if tilt < STICK_DEADZONE:
		return 0.0
	return walk_speed if tilt < STICK_RUN else run_speed

## World-space facing (the body itself is never rotated).
func get_facing_dir() -> Vector3:
	var yaw := visual.rotation.y if visual else 0.0
	return Vector3(sin(yaw), 0, cos(yaw))

func get_ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func _physics_process(delta: float) -> void:
	var input_v := _read_move_input()
	var top_speed := speed_for_tilt(input_v.length())
	var wish_dir := Vector3(input_v.x, 0, input_v.y).normalized() if top_speed > 0.0 else Vector3.ZERO
	var target := wish_dir * top_speed
	var horiz := Vector3(velocity.x, 0, velocity.z)
	var rate := acceleration if target.length() > horiz.length() else deceleration
	horiz = horiz.move_toward(target, rate * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	if wish_dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(wish_dir.x, wish_dir.z), minf(turn_speed * delta, 1.0))
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	if anim_tree == null:
		return
	var spd := get_ground_speed()
	anim_tree.set(BLEND_PARAM, clampf(spd, 0.0, run_speed))
	anim_tree.set(TIMESCALE_PARAM, playback_scale(spd))

## Clip playback rate that makes the planted foot move at the body's speed: walk_speed /
## walk_clip_speed on the Walking point, run_speed / run_clip_speed on Running, blended in
## between, 1x at Idle. Past the run point (e.g. future speed buffs) the cycle keeps speeding up.
func playback_scale(spd: float) -> float:
	var walk_k := walk_speed / walk_clip_speed if walk_clip_speed > 0.0 else 1.0
	var run_k := run_speed / run_clip_speed if run_clip_speed > 0.0 else 1.0
	if spd <= walk_speed:
		return lerpf(1.0, walk_k, spd / walk_speed)
	if spd <= run_speed:
		return lerpf(walk_k, run_k, (spd - walk_speed) / (run_speed - walk_speed))
	return run_k * spd / run_speed
