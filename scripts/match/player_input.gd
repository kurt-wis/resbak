class_name PlayerInput
extends Node

## The local player's input source: reads the bindings (Controls) and the mouse, and hands
## the host one InputFrame per tick (MatchHost.input_sources[slot] = this).
## Mouse aim is the cursor projected on the ground plane through the match camera; gamepad
## aims with the right stick and falls back to facing movement at rest.
## Movement is camera-relative (the isometric camera is turned 45 deg and can flip): the stick or
## WASD is rotated by the camera's view yaw, latched when a gesture starts so the camera's slow
## swivel never bends a run. Frames leave here in world space; the host never knows the camera.

var camera: Camera3D
var last_device_gamepad := false
var enabled := true: ## off while a menu or the scoreboard has focus
	set(value):
		enabled = value
		if not enabled:
			clear_touch() # the offline host may stop ticking during pause
var _ref_yaw := 0.0
var _moving := false
var ui_pointer_captured := false
var mouse_controls_active := false
var touch_skill_button := 0
var touch_skill_direction := Vector2.ZERO
var touch_skill_cancelled := false
var touch_skill_fraction := -1.0
var _skill_release_fraction := -1.0
var _skill_release_button := 0
var _skill_release_direction := Vector2.ZERO
var touch_active := false
var touch_move := Vector2.ZERO
var touch_target: Hero
const TARGET_TAP_RADIUS := 70.0 ## screen pixels at the 1920x1080 reference size
var tag_aiming := false
var tag_aim_cancelled := false
var _manual_tag_aim := Vector2.ZERO
var _tag_release_pending := false
var _manual_selection := false
var _tag_press_cursor := Vector2.ZERO

func begin_tag_aim() -> void:
	tag_aiming = true
	_manual_selection = false
	_tag_press_cursor = get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO
	tag_aim_cancelled = false
	_manual_tag_aim = Vector2.ZERO

func drag_tag_aim(offset: Vector2, tuning: Tuning) -> void:
	# Cancellation belongs to the explicit HUD target, never drag distance.
	if offset.length() >= tuning.tag_aim_drag_pixels:
		_manual_selection = true
		var mc := camera as MatchCamera
		_manual_tag_aim = to_world(offset.normalized(), mc.view_yaw()) if mc else offset.normalized()
		touch_target = null

func finish_tag_aim(cancelled := false) -> void:
	if tag_aiming and not cancelled and not tag_aim_cancelled:
		_tag_release_pending = true
	else:
		_manual_selection = false
		_manual_tag_aim = Vector2.ZERO
	tag_aiming = false
	tag_aim_cancelled = false

var _touch_pressed := 0
var _touch_held := 0

func begin_touch_skill(button: int) -> void:
	touch_active = true
	touch_skill_button = button
	touch_skill_direction = Vector2.ZERO
	touch_skill_cancelled = false
	touch_skill_fraction = -1.0

func drag_touch_skill(offset: Vector2, tuning: Tuning) -> void:
	# Long drags clamp aim distance; only the HUD cancel target cancels.
	if offset.length() >= tuning.tag_aim_drag_pixels:
		var mc := camera as MatchCamera
		touch_skill_direction = to_world(offset.normalized(), mc.view_yaw()) if mc else offset.normalized()
		touch_skill_fraction = clampf(offset.length() / tuning.skill_aim_pad_radius, 0.0, 1.0)

func finish_touch_skill(cancelled := false) -> void:
	if touch_skill_button != 0 and not cancelled and not touch_skill_cancelled:
		_touch_pressed |= touch_skill_button
		_skill_release_direction = touch_skill_direction
		_skill_release_fraction = touch_skill_fraction
		_skill_release_button = touch_skill_button
	touch_skill_button = 0
	touch_skill_direction = Vector2.ZERO
	touch_skill_cancelled = false

## Read-only preview input: identical point selection to the eventual release frame.
func skill_preview_frame(hero: Hero) -> InputFrame:
	var frame := InputFrame.new()
	frame.from_gamepad = last_device_gamepad or touch_active
	frame.aim_dir = touch_skill_direction if touch_skill_direction != Vector2.ZERO else Vector2(hero.aim.x, hero.aim.z)
	if touch_skill_button != 0:
		SkillAim.apply_input(frame, hero, touch_skill_button, touch_skill_direction, touch_skill_fraction)
	return frame

func set_touch_move(value: Vector2) -> void:
	touch_active = true
	touch_move = value.limit_length()

func press_touch(button: int) -> void:
	touch_active = true
	_touch_pressed |= button
	# TAG is a single edge; holding a finger never repeats or charges it.
	if button != RB.BTN_TAG:
		_touch_held |= button

func release_touch(button: int) -> void:
	_touch_held &= ~button

func clear_touch() -> void:
	ui_pointer_captured = false
	mouse_controls_active = false
	touch_skill_button = 0
	touch_skill_direction = Vector2.ZERO
	touch_skill_cancelled = false
	_skill_release_direction = Vector2.ZERO
	_skill_release_fraction = -1.0
	_skill_release_button = 0
	touch_skill_fraction = -1.0
	touch_target = null
	tag_aiming = false
	tag_aim_cancelled = false
	_tag_release_pending = false
	_manual_selection = false
	_manual_tag_aim = Vector2.ZERO
	touch_move = Vector2.ZERO
	_touch_pressed = 0
	_touch_held = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_touch()

func _ready() -> void:
	Controls.ensure()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_active = true
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if (event is InputEventMouse or event is InputEventKey) and (ui_pointer_captured or _touch_pressed != 0 or _tag_release_pending):
		return # the on-screen pad owns this gesture, not the world-click binding
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		if touch_active:
			clear_touch()
		last_device_gamepad = true
		touch_active = false
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
			finish_tag_aim(true)
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		if touch_active:
			clear_touch()
		last_device_gamepad = false
		touch_active = false

func frame_for(hero: Hero, host: MatchHost) -> InputFrame:
	var f := InputFrame.new()
	f.from_gamepad = last_device_gamepad or touch_active
	if not enabled:
		clear_touch()
		return f
	var raw := touch_move if touch_active else Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.0).limit_length()
	if touch_active and mouse_controls_active and touch_move == Vector2.ZERO:
		raw = Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.0).limit_length()
	var mc := camera as MatchCamera
	if mc:
		if raw.length() > 0.01 and (not _moving or mc.is_flipping()):
			_ref_yaw = mc.view_yaw()
		_moving = raw.length() > 0.01
		f.move = to_world(raw, _ref_yaw)
	else:
		f.move = raw
	if touch_active:
		var intended := f.move.normalized() if f.move.length() > hero.tuning.stick_dead_zone else Vector2(hero.aim.x, hero.aim.z)
		_update_touch_target(hero, host, _manual_tag_aim if _manual_tag_aim != Vector2.ZERO else intended)
		f.aim_dir = touch_skill_direction if touch_skill_direction != Vector2.ZERO else (_skill_release_direction if _skill_release_direction != Vector2.ZERO else intended)
		if is_instance_valid(touch_target):
			var direction := RB.flat(touch_target.global_position - hero.global_position).normalized()
			f.tag_aim_dir = Vector2(direction.x, direction.z) # independent of skill/movement aim
			f.tag_target_slot = touch_target.slot
		elif _manual_tag_aim != Vector2.ZERO:
			f.tag_aim_dir = _manual_tag_aim
		var skill_button := touch_skill_button if touch_skill_button != 0 else _skill_release_button
		if skill_button != 0:
			SkillAim.apply_input(f, hero, skill_button, touch_skill_direction if touch_skill_button != 0 else _skill_release_direction, touch_skill_fraction if touch_skill_button != 0 else _skill_release_fraction)
		f.pressed = _touch_pressed
		f.held = _touch_held
		_touch_pressed = 0
		_skill_release_direction = Vector2.ZERO
		_skill_release_button = 0
		_skill_release_fraction = -1.0
		_complete_tag_release(f, hero)
		return f
	var manual_stick := false
	if last_device_gamepad:
		var a := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.0)
		manual_stick = a.length() > 0.3
		if manual_stick:
			f.aim_dir = (to_world(a, mc.view_yaw()) if mc else a).normalized()
		elif f.move.length() > 0.15:
			f.aim_dir = f.move.normalized()
	elif camera:
		var p := ground_point(camera, camera.get_viewport().get_mouse_position(), hero.global_position.y)
		if p != Vector3.INF:
			f.aim_point = p
			f.has_aim = true
	if Input.is_action_just_pressed("tag") and hero.can_press_tag() and not ui_pointer_captured:
		begin_tag_aim()
	if tag_aiming and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		finish_tag_aim(true)
	if Input.is_action_just_released("tag"):
		finish_tag_aim()
	var intended := f.aim_direction(hero.global_position)
	if intended == Vector3.ZERO:
		intended = hero.aim
	# Mouse/right-stick aim chooses the direction while held. A plain tap uses nearest acquisition.
	if tag_aiming and ((last_device_gamepad and manual_stick) or (not last_device_gamepad and get_viewport().get_mouse_position().distance_to(_tag_press_cursor) > hero.tuning.tag_aim_drag_pixels)):
		_manual_selection = true
	_update_touch_target(hero, host, Vector2(intended.x, intended.z))
	if is_instance_valid(touch_target):
		var direction := RB.flat(touch_target.global_position - hero.global_position).normalized()
		f.tag_aim_dir = Vector2(direction.x, direction.z)
		f.tag_target_slot = touch_target.slot
	_complete_tag_release(f, hero)
	var map := {"skill_1": RB.BTN_SKILL1, "skill_2": RB.BTN_SKILL2, "interact": RB.BTN_INTERACT, "ping": RB.BTN_PING}
	for action in map:
		if Input.is_action_pressed(action):
			f.held |= map[action]
		if Input.is_action_just_pressed(action):
			f.pressed |= map[action]
	return f

func _complete_tag_release(f: InputFrame, hero: Hero) -> void:
	if not hero.can_press_tag():
		tag_aiming = false
		tag_aim_cancelled = false
		_tag_release_pending = false
		_manual_tag_aim = Vector2.ZERO
		_manual_selection = false
	f.tag_preparing = tag_aiming and not tag_aim_cancelled
	if _tag_release_pending:
		f.pressed |= RB.BTN_TAG
		_tag_release_pending = false
		_manual_tag_aim = Vector2.ZERO
		_manual_selection = false

## Target retention is a local input aid. It never increases tag reach or tracks a hidden foe.
func valid_touch_target(hero: Hero, host: MatchHost, candidate: Hero, max_range: float) -> bool:
	return is_instance_valid(candidate) and host.can_tag(hero, candidate) and not candidate.is_warded() \
		and host.visibility(hero, candidate) >= 0.5 and host.tag_system.reach_clear(hero, candidate.global_position) \
		and RB.flat_dist(hero.global_position, candidate.global_position) <= max_range

func _update_touch_target(hero: Hero, host: MatchHost, intended: Vector2) -> void:
	if not host.round_live() or not hero.is_free() or not bool(host.settings.get("tag_assist", true)):
		touch_target = null
		return
	var auto_tap := (tag_aiming or _tag_release_pending) and not _manual_selection
	if _manual_selection or auto_tap:
		touch_target = null
	if valid_touch_target(hero, host, touch_target, hero.tag_reach() + host.tuning.body_radius * 2.0):
		return # moving backwards does not rotate aim away from the current target
	touch_target = null
	var best_distance := INF
	var best_range := INF
	var direction := Vector3(intended.x, 0, intended.y)
	if direction == Vector3.ZERO:
		return
	for enemy in host.enemies_of(hero):
		if not valid_touch_target(hero, host, enemy, hero.tag_reach() + host.tuning.body_radius * 2.0):
			continue
		var to := RB.flat(enemy.global_position - hero.global_position)
		if not auto_tap and to.length() > 0.001 and rad_to_deg(direction.angle_to(to.normalized())) > host.tuning.tag_assist_angle_deg:
			continue
		var score := direction.angle_to(to.normalized()) if _manual_selection else to.length()
		if score < best_distance or (is_equal_approx(score, best_distance) and to.length() < best_range):
			best_distance = score
			best_range = to.length()
			touch_target = enemy

## Tap a visible opponent to switch the lock without firing a tag.
func select_touch_target(hero: Hero, host: MatchHost, screen: Vector2) -> bool:
	if camera == null or not enabled or not host.round_live() or not hero.is_free() or not bool(host.settings.get("tag_assist", true)):
		return false
	var best: Hero = null
	var distance := TARGET_TAP_RADIUS
	for enemy in host.enemies_of(hero):
		if not valid_touch_target(hero, host, enemy, hero.tag_reach() + host.tuning.body_radius * 2.0):
			continue
		var point := enemy.global_position + Vector3.UP * enemy.data.model_height * 0.5
		if camera.is_position_behind(point):
			continue
		var d := camera.unproject_position(point).distance_to(screen)
		if d < distance:
			distance = d
			best = enemy
	if best == null:
		return false
	touch_active = true
	touch_target = best
	return true

## A screen-relative stick vector (x right, y down) turned into world XZ by a camera yaw.
static func to_world(v: Vector2, yaw: float) -> Vector2:
	var w := Basis(Vector3.UP, yaw) * Vector3(v.x, 0.0, v.y)
	return Vector2(w.x, w.z)

## Cursor -> point on the horizontal plane at height y, or Vector3.INF.
static func ground_point(cam: Camera3D, screen: Vector2, y := 0.0) -> Vector3:
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (y - origin.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return origin + dir * t
