class_name InputFrame
extends RefCounted

## One player's (or bot's) input for one host tick (docs/RESBAK.md § 12 "Engine and
## networking"): move vector, aim, held buttons, and the presses queued since last tick.
## Gameplay reads only these, never Input directly, so local players, bots and (later)
## remote clients all drive heroes the same way.

## Stick-scaled move: x = screen right (+X world), y = screen down (+Z world). The camera
## never rotates, so screen and world axes line up. Length is the stick tilt (keys = 1).
var move := Vector2.ZERO
## Where the player aims, on the ground plane (y ignored). `has_aim` false = face movement.
var aim_point := Vector3.ZERO
var has_aim := false
## Gamepad/bot aim direction (used when there is no aim point). Zero = none.
var aim_dir := Vector2.ZERO
var held := 0 ## RB.BTN_* bits held this tick
var pressed := 0 ## RB.BTN_* bits pressed since the previous tick (edges)
var from_gamepad := false ## enables tag assist and the 15-50 % walk band

func is_held(button: int) -> bool:
	return held & button != 0

func was_pressed(button: int) -> bool:
	return pressed & button != 0

func duplicate_frame() -> InputFrame:
	var f := InputFrame.new()
	f.move = move
	f.aim_point = aim_point
	f.has_aim = has_aim
	f.aim_dir = aim_dir
	f.held = held
	f.pressed = pressed
	f.from_gamepad = from_gamepad
	return f

## World-space aim direction for `from` (flat, normalized), or Vector3.ZERO if none.
func aim_direction(from: Vector3) -> Vector3:
	if has_aim:
		var d := Vector3(aim_point.x - from.x, 0.0, aim_point.z - from.z)
		if d.length() > 0.05:
			return d.normalized()
	if aim_dir.length() > 0.1:
		return Vector3(aim_dir.x, 0.0, aim_dir.y).normalized()
	return Vector3.ZERO

## Distance from `from` to the aim point (flat), or -1 when aiming by direction only.
func aim_distance(from: Vector3) -> float:
	if has_aim:
		return Vector2(aim_point.x - from.x, aim_point.z - from.z).length()
	return -1.0
