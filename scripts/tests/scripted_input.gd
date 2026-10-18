class_name ScriptedInput
extends RefCounted

## Test input source: per-slot held state plus one-tick presses. press() queues a button
## press for the next tick only; hold()/release() keep a button down; move/aim persist.

var _move := {}
var _aim := {}
var _held := {}
var _pressed := {}
var gamepad := false

func move(h: Hero, v: Vector2) -> void:
	_move[h.slot] = v

func aim_at(h: Hero, p: Vector3) -> void:
	_aim[h.slot] = p

func press(h: Hero, button: int) -> void:
	_pressed[h.slot] = int(_pressed.get(h.slot, 0)) | button

func hold(h: Hero, button: int) -> void:
	if int(_held.get(h.slot, 0)) & button == 0:
		_pressed[h.slot] = int(_pressed.get(h.slot, 0)) | button
	_held[h.slot] = int(_held.get(h.slot, 0)) | button

func release(h: Hero, button: int) -> void:
	_held[h.slot] = int(_held.get(h.slot, 0)) & ~button

func clear(h: Hero) -> void:
	_move.erase(h.slot)
	_aim.erase(h.slot)
	_held.erase(h.slot)
	_pressed.erase(h.slot)

func frame_for(h: Hero, _host: MatchHost) -> InputFrame:
	var f := InputFrame.new()
	f.from_gamepad = gamepad
	f.move = _move.get(h.slot, Vector2.ZERO)
	if _aim.has(h.slot):
		f.aim_point = _aim[h.slot]
		f.has_aim = true
	f.pressed = int(_pressed.get(h.slot, 0))
	# A press() is held for one tick; explicit hold()/release() keep it down.
	# Tag uses only the pressed edge, independent of held state.
	f.held = int(_held.get(h.slot, 0)) | f.pressed
	_pressed.erase(h.slot)
	return f
