class_name MatchCamera
extends Camera3D

## Match camera (docs/RESBAK.md § 1): top-down three-quarter, hero centred, never rotates;
## 55 deg down pitch, 22 m from the hero, 40 deg vertical FOV; the court's long axis runs
## left-right with Dilaw on the left for everyone. High ground zooms out 15 % (zoom_out).
## Shake respects Settings > Camera shake and Reduce camera motion.

@export var pitch_deg := 55.0
@export var distance := 22.0
@export var fov_deg := 40.0
var target: Node3D
var zoom_out := 0.0 ## 0..1, 1 = +15 % distance (high ground)
var _focus := Vector3.ZERO
var _shake := 0.0
var _shake_time := 0.0

func _ready() -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = fov_deg
	near = 0.5
	far = 220.0
	current = true
	if target:
		_focus = target.global_position
	_place(Vector3.ZERO)

func snap() -> void:
	if target:
		_focus = target.global_position
	_place(Vector3.ZERO)

func shake(amount: float, time := 0.25) -> void:
	var save := get_node_or_null("/root/Save")
	var scale := 0.7
	if save:
		if bool(save.get_setting("accessibility", "reduce_motion")):
			return
		scale = float(save.get_setting("gameplay", "camera_shake"))
	_shake = maxf(_shake, amount * scale)
	_shake_time = maxf(_shake_time, time)

func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		_focus = _focus.lerp(target.global_position, 1.0 - exp(-12.0 * delta))
	var jitter := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
		if _shake_time <= 0.0:
			_shake = 0.0
	_place(jitter)

func _place(jitter: Vector3) -> void:
	var d := distance * (1.0 + 0.15 * zoom_out)
	var pitch := deg_to_rad(pitch_deg)
	var look_at_point := _focus + Vector3(0, 0.8, 0)
	global_position = look_at_point + Vector3(0, sin(pitch) * d, cos(pitch) * d) + jitter
	look_at(look_at_point + jitter, Vector3.UP)
