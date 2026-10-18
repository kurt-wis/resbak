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
var enabled := true ## off while a menu or the scoreboard has focus
var _ref_yaw := 0.0
var _moving := false

func _ready() -> void:
	Controls.ensure()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		last_device_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		last_device_gamepad = false

func frame_for(hero: Hero, _host: MatchHost) -> InputFrame:
	var f := InputFrame.new()
	f.from_gamepad = last_device_gamepad
	if not enabled:
		return f
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.0).limit_length()
	var mc := camera as MatchCamera
	if mc:
		if raw.length() > 0.01 and (not _moving or mc.is_flipping()):
			_ref_yaw = mc.view_yaw()
		_moving = raw.length() > 0.01
		f.move = to_world(raw, _ref_yaw)
	else:
		f.move = raw
	if last_device_gamepad:
		var a := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.0)
		if a.length() > 0.3:
			f.aim_dir = (to_world(a, mc.view_yaw()) if mc else a).normalized()
		elif f.move.length() > 0.15:
			f.aim_dir = f.move.normalized()
	elif camera:
		var p := ground_point(camera, camera.get_viewport().get_mouse_position(), hero.global_position.y)
		if p != Vector3.INF:
			f.aim_point = p
			f.has_aim = true
	var map := {"tag": RB.BTN_TAG, "skill_1": RB.BTN_SKILL1, "skill_2": RB.BTN_SKILL2, "interact": RB.BTN_INTERACT, "ping": RB.BTN_PING}
	for action in map:
		if Input.is_action_pressed(action):
			f.held |= map[action]
		if Input.is_action_just_pressed(action):
			f.pressed |= map[action]
	return f

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
