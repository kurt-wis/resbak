class_name BatangHamogController
extends CharacterBody3D

## Batang Hamog — Movement/Rescue controller with Dire-Diretso, Harurot, Lusot.
## Reads ProjectSettings InputMap actions: move_* / skill_harurot / skill_lusot / action_tag.

enum State { GROUND, HARUROT, HARUROT_RECOVERY, LUSOT_SLIDE, LUSOT_RECOVERY, LUSOT_VAULT }

@export var base_speed: float = 5.0
@export var sprint_multiplier: float = 1.0 ## sprint removed; Shift is Harurot now
@export var harurot_speed_multiplier: float = 2.2 ## 120% bonus multiplicatively (1.0 + 1.2)
@export var harurot_duration: float = 1.2
@export var harurot_turn_speed: float = 18.0
@export var harurot_cooldown_max: float = 2.0
@export var harurot_recovery_time: float = 0.35
@export var lusot_slide_duration: float = 0.7
@export var lusot_recovery_duration: float = 0.25
@export var vault_duration: float = 0.58
@export var vault_hop_velocity: float = 3.2

var state: int = State.GROUND
var dire_diretso: DireDiretsoComponent
var is_carrying_flag: bool = false:
	set(v):
		is_carrying_flag = v
		if dire_diretso:
			dire_diretso.force_flag_carry(v)

var harurot_timer: float = 0.0
var harurot_cooldown: float = 0.0
var recovery_timer: float = 0.0
var lusot_timer: float = 0.0
var tag_lockout_timer: float = 0.0
var vault_timer: float = 0.0
var slide_dir: Vector3 = Vector3.ZERO
var vault_dir: Vector3 = Vector3.ZERO

var visual: Node3D
var model: Node3D
var animator: AnimationPlayer
var body_collision: CollisionShape3D
var hurtbox: Area3D
var hurtbox_collision: CollisionShape3D
var vault_detector: Node3D
var low_cast: RayCast3D
var head_cast: RayCast3D
var orig_body_height: float = 1.6
var orig_body_radius: float = 0.35
var orig_hurt_height: float = 1.6

var idle_clip: String = ""
var walk_clip: String = ""
var run_clip: String = ""
var harurot_clip: String = ""
var lusot_slide_clip: String = ""
var lusot_vault_clip: String = ""

var external_move: Vector2 = Vector2.ZERO ## touch override from playtest UI

# VFX nodes (Phase 3)
var wind_trail: GPUParticles3D
var pushoff_burst: GPUParticles3D
var slide_dust: GPUParticles3D
var slide_mist: GPUParticles3D
var dire_wisps: GPUParticles3D

func _ready() -> void:
	_ensure_input_actions()
	floor_snap_length = 0.35
	floor_constant_speed = true
	dire_diretso = DireDiretsoComponent.new()
	dire_diretso.name = "DireDiretso"
	dire_diretso.base_run_speed = base_speed
	add_child(dire_diretso)
	_setup_collision()
	_setup_model()
	_setup_detector()
	_setup_vfx()

static func input_defs() -> Dictionary:
	return {
		"move_forward": {"keys": [KEY_W, KEY_UP], "joy_buttons": [11]},
		"move_back": {"keys": [KEY_S, KEY_DOWN], "joy_buttons": [12]},
		"move_left": {"keys": [KEY_A, KEY_LEFT], "joy_buttons": [13]},
		"move_right": {"keys": [KEY_D, KEY_RIGHT], "joy_buttons": [14]},
		"skill_harurot": {"keys": [KEY_SHIFT], "joy_buttons": [5]},
		"skill_lusot": {"keys": [KEY_CTRL, KEY_C], "joy_buttons": [1]},
		"action_tag": {"keys": [KEY_E], "mouse": true, "joy_buttons": [0]},
	}

func _ensure_input_actions() -> void:
	for action in input_defs().keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
	var defs: Dictionary = input_defs()
	for action in defs.keys():
		var cfg: Dictionary = defs[action]
		var has_key := false
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				has_key = true
				break
		if not has_key:
			for kc in cfg.get("keys", []):
				var ev := InputEventKey.new()
				ev.physical_keycode = kc
				InputMap.action_add_event(action, ev)
		if cfg.get("mouse", false):
			var has_mouse := false
			for e in InputMap.action_get_events(action):
				if e is InputEventMouseButton:
					has_mouse = true
					break
			if not has_mouse:
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT
				InputMap.action_add_event(action, mb)
		for jb in cfg.get("joy_buttons", []):
			var has_jb := false
			for e in InputMap.action_get_events(action):
				if e is InputEventJoypadButton and e.button_index == jb:
					has_jb = true
					break
			if not has_jb:
				var je := InputEventJoypadButton.new()
				je.button_index = jb
				InputMap.action_add_event(action, je)

func _setup_collision() -> void:
	body_collision = CollisionShape3D.new()
	body_collision.name = "BodyCollision"
	var cap := CapsuleShape3D.new()
	cap.radius = orig_body_radius
	cap.height = orig_body_height
	body_collision.shape = cap
	body_collision.position.y = 0.8
	add_child(body_collision)
	hurtbox = Area3D.new()
	hurtbox.name = "Hurtbox3D"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	add_child(hurtbox)
	hurtbox_collision = CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.35
	hcap.height = orig_hurt_height
	hurtbox_collision.shape = hcap
	hurtbox_collision.position.y = 0.8
	hurtbox.add_child(hurtbox_collision)

func _setup_model() -> void:
	visual = Node3D.new()
	visual.name = "CharacterVisual"
	add_child(visual)
	var packed: PackedScene = load("res://assets/characters/batang_hamog.glb") as PackedScene
	model = (packed.instantiate() as Node3D)
	model.name = "BatangHamog"
	visual.add_child(model)
	# normalize height ~1.8m
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		if not found:
			bounds = box
			found = true
		else:
			bounds = bounds.merge(box)
	if found and bounds.size.y > 0.01:
		var factor: float = 1.8 / bounds.size.y
		model.scale = Vector3.ONE * factor
		model.position.y = -bounds.position.y * factor
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animator = node as AnimationPlayer
		break
	_detect_clips()

func _detect_clips() -> void:
	if animator == null:
		return
	for clip in animator.get_animation_list():
		var low := clip.to_lower()
		var anim: Animation = animator.get_animation(clip)
		if low == "idle":
			idle_clip = clip
			anim.loop_mode = Animation.LOOP_LINEAR
		elif low == "walking":
			walk_clip = clip
			anim.loop_mode = Animation.LOOP_LINEAR
		elif low == "running":
			run_clip = clip
			anim.loop_mode = Animation.LOOP_LINEAR
		elif low == "runfast" and run_clip == "":
			run_clip = clip
			anim.loop_mode = Animation.LOOP_LINEAR
		elif low == "harurot":
			harurot_clip = clip
			anim.loop_mode = Animation.LOOP_NONE
		elif low == "lusot_slide":
			lusot_slide_clip = clip
			anim.loop_mode = Animation.LOOP_NONE
		elif low == "lusot_vault":
			lusot_vault_clip = clip
			anim.loop_mode = Animation.LOOP_NONE
	if walk_clip == "" and run_clip != "":
		walk_clip = run_clip
	if idle_clip != "":
		animator.play(idle_clip)

func _setup_detector() -> void:
	vault_detector = Node3D.new()
	vault_detector.name = "VaultDetector"
	add_child(vault_detector)
	low_cast = RayCast3D.new()
	low_cast.name = "LowObstacleCast"
	low_cast.position = Vector3(0, 0.65, 0)
	low_cast.target_position = Vector3(0, 0, 1.2)
	low_cast.collision_mask = 1
	low_cast.enabled = true
	vault_detector.add_child(low_cast)
	head_cast = RayCast3D.new()
	head_cast.name = "HeadClearanceCast"
	head_cast.position = Vector3(0, 1.45, 0)
	head_cast.target_position = Vector3(0, 0, 1.2)
	head_cast.collision_mask = 1
	head_cast.enabled = true
	vault_detector.add_child(head_cast)

func _make_particles(node_name: String, amount: int, lifetime: float, color: Color, one_shot: bool, explosiveness: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	p.one_shot = one_shot
	p.explosiveness = explosiveness
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 4, 8))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.4, 1)
	mat.spread = 32.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 3.2
	mat.gravity = Vector3(0, -2.5, 0)
	mat.scale_min = 0.06
	mat.scale_max = 0.16
	mat.color = color
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = smat
	p.draw_pass_1 = quad
	return p

func _setup_vfx() -> void:
	# Harurot wind ribbon trail: world-space so defenders can track escape vector.
	wind_trail = _make_particles("HarurotWindTrail", 48, 0.7, Color(0.45, 0.95, 1.0, 0.85), false, 0.1)
	wind_trail.position = Vector3(0, 1.0, 0.4)
	add_child(wind_trail)
	pushoff_burst = _make_particles("HarurotPushOff", 16, 0.5, Color(0.75, 0.68, 0.58, 0.9), true, 0.9)
	pushoff_burst.position = Vector3(0, 0.12, 0.3)
	add_child(pushoff_burst)
	slide_dust = _make_particles("LusotSlideDust", 32, 0.6, Color(0.8, 0.74, 0.64, 0.85), false, 0.15)
	slide_dust.position = Vector3(0, 0.15, 0.2)
	add_child(slide_dust)
	slide_mist = _make_particles("LusotMist", 16, 0.5, Color(0.85, 0.95, 1.0, 0.4), false, 0.1)
	slide_mist.position = Vector3(0, 1.2, 0)
	add_child(slide_mist)
	dire_wisps = _make_particles("DireWisps", 32, 0.4, Color(0.9, 0.9, 0.9, 0.5), false, 0.1)
	dire_wisps.position = Vector3(0, 0.1, 0)
	add_child(dire_wisps)

func _play_clip(clip_name: String, spd: float = 1.0) -> void:
	if animator == null or clip_name == "" or not animator.has_animation(clip_name):
		return
	if animator.current_animation != clip_name:
		animator.play(clip_name, 0.15, spd)
	else:
		animator.speed_scale = spd

## Recovery must go through upright Walk, never hunched Run.
func get_recovery_clip() -> String:
	return walk_clip

func is_tag_locked() -> bool:
	return tag_lockout_timer > 0.0

func on_hit_by_skill() -> void:
	if dire_diretso:
		dire_diretso.on_hit_by_skill()

func attempt_tag() -> bool:
	if is_tag_locked():
		return false
	if dire_diretso:
		dire_diretso.on_tag_attempt()
	return true

func _read_move_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if external_move.length() > 0.1:
		v = external_move
	return v.limit_length()

func _dir_from_input(v: Vector2) -> Vector3:
	return Vector3(v.x, 0, v.y)

## World-space facing. Only `visual` (and `vault_detector`) are yawed, never the body,
## so the body basis is useless here. Yaw convention: atan2(x, z) -> forward is +Z at 0.
func get_facing_dir() -> Vector3:
	var yaw := visual.rotation.y if visual else 0.0
	return Vector3(sin(yaw), 0, cos(yaw))

func try_harurot() -> bool:
	if state != State.GROUND or harurot_cooldown > 0.0:
		return false
	if harurot_clip == "":
		return false
	state = State.HARUROT
	harurot_timer = harurot_duration
	harurot_cooldown = harurot_cooldown_max
	_play_clip(harurot_clip, 1.0)
	wind_trail.emitting = true
	pushoff_burst.restart()
	return true

func try_lusot() -> bool:
	if state != State.GROUND:
		return false
	var low_hit := low_cast.is_colliding()
	var head_blocked := head_cast.is_colliding()
	if low_hit and not head_blocked and lusot_vault_clip != "":
		state = State.LUSOT_VAULT
		vault_timer = vault_duration
		# Same yaw the VaultDetector casts used, so we vault over what we detected.
		vault_dir = get_facing_dir()
		_play_clip(lusot_vault_clip, 1.0)
		velocity.y = vault_hop_velocity * 0.6
		return true
	if lusot_slide_clip == "":
		return false
	state = State.LUSOT_SLIDE
	lusot_timer = lusot_slide_duration
	var iv := _read_move_input()
	slide_dir = _dir_from_input(iv)
	if slide_dir.length() < 0.05:
		slide_dir = get_facing_dir()
	slide_dir = slide_dir.normalized()
	_lower_hurtbox(true)
	_play_clip(lusot_slide_clip, 1.0)
	slide_dust.emitting = true
	slide_mist.emitting = true
	return true

func _lower_hurtbox(lower: bool) -> void:
	var bcap := body_collision.shape as CapsuleShape3D
	var hcap := hurtbox_collision.shape as CapsuleShape3D
	if lower:
		bcap.height = orig_body_height * 0.5
		body_collision.position.y = orig_body_height * 0.25
		hcap.height = orig_hurt_height * 0.5
		hurtbox_collision.position.y = orig_hurt_height * 0.25
	else:
		bcap.height = orig_body_height
		body_collision.position.y = 0.8
		hcap.height = orig_hurt_height
		hurtbox_collision.position.y = 0.8

func _physics_process(delta: float) -> void:
	if dire_diretso == null:
		return
	harurot_cooldown = maxf(0.0, harurot_cooldown - delta)
	tag_lockout_timer = maxf(0.0, tag_lockout_timer - delta)
	var input_v := _read_move_input()
	var wish_dir := _dir_from_input(input_v)
	# skill triggers (edge)
	if Input.is_action_just_pressed("skill_harurot"):
		try_harurot()
	if Input.is_action_just_pressed("skill_lusot"):
		try_lusot()
	if Input.is_action_just_pressed("action_tag"):
		attempt_tag()
	match state:
		State.GROUND:
			var speed := base_speed * dire_diretso.speed_bonus()
			velocity.x = wish_dir.x * speed
			velocity.z = wish_dir.z * speed
			if wish_dir.length() > 0.1:
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(wish_dir.x, wish_dir.z), minf(15.0 * delta, 1.0))
				vault_detector.rotation.y = visual.rotation.y
				if speed >= base_speed * 1.4:
					_play_clip(run_clip, 1.1)
				elif speed > 0.1:
					_play_clip(walk_clip, 1.05)
			else:
				_play_clip(idle_clip, 1.0)
			dire_diretso.update_momentum(delta, Vector3(velocity.x, 0, velocity.z))
			_update_dire_vfx()
		State.HARUROT:
			harurot_timer -= delta
			var burst_speed := base_speed * harurot_speed_multiplier * dire_diretso.speed_bonus()
			var cur := Vector3(velocity.x, 0, velocity.z)
			if cur.length() < burst_speed * 0.5:
				cur = wish_dir * burst_speed if wish_dir.length() > 0.05 else get_facing_dir() * burst_speed
			if wish_dir.length() > 0.1:
				var cur_yaw := atan2(cur.x, cur.z)
				var want_yaw := atan2(wish_dir.x, wish_dir.z)
				var new_yaw := rotate_toward(cur_yaw, want_yaw, harurot_turn_speed * delta)
				cur = Vector3(sin(new_yaw), 0, cos(new_yaw)) * burst_speed
				visual.rotation.y = lerp_angle(visual.rotation.y, new_yaw, minf(20.0 * delta, 1.0))
				vault_detector.rotation.y = visual.rotation.y
			velocity.x = cur.x
			velocity.z = cur.z
			# no immunity: Hurtbox stays enabled (never disabled)
			if harurot_timer <= 0.0:
				state = State.HARUROT_RECOVERY
				recovery_timer = harurot_recovery_time
				wind_trail.emitting = false
		State.HARUROT_RECOVERY:
			recovery_timer -= delta
			# CRITICAL: upright Walk only, never hunched Run.
			_play_clip(get_recovery_clip(), 1.0)
			var rspeed := base_speed * dire_diretso.speed_bonus()
			velocity.x = wish_dir.x * rspeed
			velocity.z = wish_dir.z * rspeed
			dire_diretso.update_momentum(delta, Vector3(velocity.x, 0, velocity.z))
			if recovery_timer <= 0.0:
				state = State.GROUND
		State.LUSOT_SLIDE:
			lusot_timer -= delta
			var slide_speed := maxf(Vector3(velocity.x, 0, velocity.z).length(), base_speed * 1.2)
			velocity.x = slide_dir.x * slide_speed
			velocity.z = slide_dir.z * slide_speed
			if lusot_timer <= 0.0:
				_lower_hurtbox(false)
				slide_dust.emitting = false
				slide_mist.emitting = false
				state = State.LUSOT_RECOVERY
				lusot_timer = lusot_recovery_duration
				tag_lockout_timer = lusot_recovery_duration
				_play_clip(get_recovery_clip(), 1.0)
		State.LUSOT_RECOVERY:
			lusot_timer -= delta
			var gspeed := base_speed * dire_diretso.speed_bonus()
			velocity.x = wish_dir.x * gspeed
			velocity.z = wish_dir.z * gspeed
			if lusot_timer <= 0.0:
				state = State.GROUND
		State.LUSOT_VAULT:
			vault_timer -= delta
			# preserve forward velocity over obstacle; Dire stacks preserved (no reset)
			var vspeed := maxf(Vector3(velocity.x, 0, velocity.z).length(), base_speed)
			velocity.x = vault_dir.x * vspeed
			velocity.z = vault_dir.z * vspeed
			if vault_timer <= 0.0:
				state = State.GROUND
				_play_clip(run_clip if wish_dir.length() > 0.1 else idle_clip, 1.0)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		if state != State.LUSOT_VAULT:
			velocity.y = 0.0
		elif velocity.y < 0.0 and is_on_floor():
			pass
	move_and_slide()

func _update_dire_vfx() -> void:
	if dire_wisps == null or dire_diretso == null:
		return
	var s := dire_diretso.momentum_stacks
	if s <= 0:
		dire_wisps.emitting = false
	else:
		dire_wisps.emitting = true
		dire_wisps.amount_ratio = float(s) / 4.0
