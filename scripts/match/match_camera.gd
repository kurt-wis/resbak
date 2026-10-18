class_name MatchCamera
extends Camera3D

## Match camera: Kurt's isometric court framing (map-art, court_playtest.gd), ported to the match.
## Orthographic, 35.264 deg down, yawed so the player's own end is nearest and the enemy base is
## "up the screen", then turned 45 deg courtside. A small swivel (up to 6 deg) follows the hero's
## lateral position, the view leads the hero's motion and looks 1.4 m ahead toward the enemy end.
## Mouse wheel zooms (view size 8..15), camera_flip (V / right stick) turns the view 180 deg in
## 0.65 s. Presentation only: PlayerInput reads view_yaw() to turn screen-relative movement into
## world directions, so InputFrames stay in world space and bots never see the camera.
## Round-1 intro (2026-10-17): MatchView sets intro_w (0..1), intro_focus and intro_size each
## frame; the camera blends its normal framing toward that flyover pose (the yaw is untouched
## so screen-relative movement stays right the moment the intro ends).
## Shake respects Settings > Camera shake and Reduce camera motion.

const COURTSIDE_ANGLE := 45.0
const FLIP_DURATION := 0.65
const MIN_SIZE := 8.0
const MAX_SIZE := 15.0

@export var pitch_deg := -35.264
@export var arm := 20.0
@export var base_size := 10.2 ## orthographic view height in metres (wheel changes it)
@export var run_widen := 1.0 ## extra view size at full run
@export var ahead := 1.4 ## metres the focus sits toward the enemy end
@export var lead_time := 0.18 ## seconds of velocity the focus leads by
@export var swivel_deg := 6.0
var target: Node3D
var bounds := Rect2() ## play area (XZ); empty = no clamp
var enemy_dir := Vector3.RIGHT ## toward the enemy base (set by the match scene)
var zoom_out := 0.0 ## 0..1, high ground widens the view 15 %
var ink: ShaderMaterial ## the illustrated-edges finish (focus follows the hero)
var intro_w := 0.0 ## 0 = follow the hero, 1 = the flyover pose
var intro_focus := Vector3.ZERO
var intro_size := 14.0
var yaw := 0.0
var _yaw_from := 0.0
var _yaw_to := 0.0
var _flip_t := -1.0
var _swivel := 0.0
var _size := 10.2
var _lead := Vector3.ZERO
var _focus := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _shake := 0.0
var _shake_time := 0.0

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	near = 0.08
	far = 160.0
	current = true
	snap()

## Face the enemy end and jump straight to the framed position (round start, spawn).
func snap() -> void:
	var d := RB.flat(enemy_dir)
	if d.length() < 0.01:
		d = Vector3.RIGHT
	yaw = atan2(-d.x, -d.z)
	_yaw_to = yaw
	_flip_t = -1.0
	_lead = Vector3.ZERO
	_size = base_size
	if target:
		_last_pos = target.global_position
	_place(0.0)

## Turn the view to look from the other end (camera_flip).
func flip() -> void:
	_yaw_from = yaw
	_yaw_to = wrapf(_yaw_to + PI, -PI, PI)
	_flip_t = 0.0

func is_flipping() -> bool:
	return _flip_t >= 0.0

## The yaw screen-up maps to: PlayerInput rotates the move stick by this.
func view_yaw() -> float:
	return yaw + deg_to_rad(COURTSIDE_ANGLE) + _swivel

## A screen-space direction (x right, y down) as a flat world direction.
func screen_to_world(v: Vector2) -> Vector2:
	var w := Basis(Vector3.UP, view_yaw()) * Vector3(v.x, 0.0, v.y)
	return Vector2(w.x, w.z)

func shake(amount: float, time := 0.25) -> void:
	var save := get_node_or_null("/root/Save")
	var scale := 0.7
	if save:
		if bool(save.get_setting("accessibility", "reduce_motion")):
			return
		scale = float(save.get_setting("gameplay", "camera_shake"))
	_shake = maxf(_shake, amount * scale)
	_shake_time = maxf(_shake_time, time)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			base_size = maxf(MIN_SIZE, base_size - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			base_size = minf(MAX_SIZE, base_size + 0.5)
	if InputMap.has_action("camera_flip") and event.is_action_pressed("camera_flip") and not event.is_echo():
		flip()

func _process(delta: float) -> void:
	if _flip_t >= 0.0:
		_flip_t = minf(_flip_t + delta, FLIP_DURATION)
		yaw = lerp_angle(_yaw_from, _yaw_to, smoothstep(0.0, 1.0, _flip_t / FLIP_DURATION))
		if _flip_t >= FLIP_DURATION:
			yaw = _yaw_to
			_flip_t = -1.0
	_place(delta)

func _clamped(p: Vector3) -> Vector3:
	if bounds.size == Vector2.ZERO:
		return p
	var m := 3.0
	return Vector3(clampf(p.x, bounds.position.x + m, bounds.end.x - m), p.y, clampf(p.z, bounds.position.y + m, bounds.end.y - m))

func _place(delta: float) -> void:
	var pos := _last_pos
	var vel := Vector3.ZERO
	if target and is_instance_valid(target):
		pos = target.global_position
		if delta > 0.0:
			vel = RB.flat(pos - _last_pos) / delta
			if vel.length() > 20.0: # teleports (respawn, jail) are not motion
				vel = Vector3.ZERO
		_last_pos = pos
	var court_right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var centre := Vector3(bounds.get_center().x, 0, bounds.get_center().y) if bounds.size != Vector2.ZERO else Vector3.ZERO
	var lateral := (pos - centre).dot(court_right)
	var want_swivel := 0.0 if _flip_t >= 0.0 else deg_to_rad(swivel_deg) * clampf(lateral / 12.0, -1.0, 1.0)
	var run := clampf(vel.length() / 6.0, 0.0, 1.0)
	var want_size := (base_size + run_widen * run) * (1.0 + 0.15 * zoom_out)
	var want_lead := vel * lead_time
	if delta <= 0.0:
		_swivel = want_swivel
		_size = want_size
		_lead = want_lead
	else:
		_swivel = lerp_angle(_swivel, want_swivel, 1.0 - exp(-2.0 * delta))
		_size = lerpf(_size, want_size, 1.0 - exp(-2.5 * delta))
		_lead = _lead.lerp(want_lead, 1.0 - exp(-4.0 * delta))
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -ahead)
	var goal := _clamped(pos + fwd + _lead) + Vector3(0, 1.4, 0)
	_focus = goal if delta <= 0.0 else _focus.lerp(goal, 1.0 - exp(-8.0 * delta))
	var shown_focus := _focus
	size = _size
	if intro_w > 0.0:
		shown_focus = _focus.lerp(intro_focus, intro_w)
		size = lerpf(_size, intro_size, intro_w)
	var orbit := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), view_yaw(), 0))
	var jitter := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		jitter = orbit * Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
		if _shake_time <= 0.0:
			_shake = 0.0
	global_basis = orbit
	global_position = shown_focus + orbit * Vector3(0, 0, arm) + jitter
	_update_ink(pos)

## Kurt's distance focus: the ink-edge shader keeps a circle of ground around the hero sharp and
## softens what lies further away (clear_radius / blur_radius in the shader), so walking toward
## something brings it into focus. The round-1 flyover shows the whole yard, so it fades out there.
func _update_ink(pos: Vector3) -> void:
	if ink == null or not is_inside_tree():
		return
	ink.set_shader_parameter("focus_world", pos)
	ink.set_shader_parameter("distance_focus_enabled", 1.0 - clampf(intro_w, 0.0, 1.0))
	var vp := get_viewport()
	if vp:
		var sz := vp.get_visible_rect().size
		if sz.x > 0.0 and sz.y > 0.0:
			ink.set_shader_parameter("player_focus_uv", unproject_position(pos + Vector3(0, 0.8, 0)) / sz)
