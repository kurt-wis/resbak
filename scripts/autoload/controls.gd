class_name Controls
extends RefCounted

## Default bindings (docs/RESBAK.md § 9 Controls), registered at runtime so Settings can
## rebind them later (Save keeps overrides in settings.cfg [controls]). Call Controls.ensure()
## before reading input; it only adds actions that are missing.
## Mouse aims; the hero faces the aim when standing and when tagging or casting.

const DEFS := {
	"move_forward": {"keys": [KEY_W, KEY_UP], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"move_back": {"keys": [KEY_S, KEY_DOWN], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	"move_left": {"keys": [KEY_A, KEY_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"aim_left": {"axes": [[JOY_AXIS_RIGHT_X, -1.0]]},
	"aim_right": {"axes": [[JOY_AXIS_RIGHT_X, 1.0]]},
	"aim_up": {"axes": [[JOY_AXIS_RIGHT_Y, -1.0]]},
	"aim_down": {"axes": [[JOY_AXIS_RIGHT_Y, 1.0]]},
	"tag": {"mouse": [MOUSE_BUTTON_LEFT], "axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	"skill_1": {"keys": [KEY_Q], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	"skill_2": {"keys": [KEY_E], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"interact": {"keys": [KEY_F], "buttons": [JOY_BUTTON_A]},
	"ping": {"keys": [KEY_G], "mouse": [MOUSE_BUTTON_MIDDLE], "buttons": [JOY_BUTTON_DPAD_UP]},
	"banter": {"keys": [KEY_T], "buttons": [JOY_BUTTON_DPAD_DOWN]},
	"scoreboard": {"keys": [KEY_C], "buttons": [JOY_BUTTON_BACK]}, ## not Tab: Alt+Tab would open it
	"menu": {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_START]},
	"hide_hud": {"keys": [KEY_F10]},
	"camera_flip": {"keys": [KEY_V], "buttons": [JOY_BUTTON_RIGHT_STICK]}, ## turn the view 180 deg
}

## Human-readable key labels for HUD prompts (keyboard/mouse; gamepad labels via Button icons later).
const KEY_LABELS := {"tag": "LMB", "skill_1": "Q", "skill_2": "E", "interact": "F", "ping": "G", "scoreboard": "C", "camera_flip": "V"}
const PAD_LABELS := {"tag": "RT", "skill_1": "LB", "skill_2": "RB", "interact": "A", "ping": "D-pad up", "scoreboard": "View", "camera_flip": "R3"}

static func ensure() -> void:
	for action in DEFS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.15)
		var d: Dictionary = DEFS[action]
		for k in d.get("keys", []):
			var e := InputEventKey.new()
			e.physical_keycode = k
			_add(action, e)
		for b in d.get("mouse", []):
			var m := InputEventMouseButton.new()
			m.button_index = b
			_add(action, m)
		for b in d.get("buttons", []):
			var j := InputEventJoypadButton.new()
			j.button_index = b
			_add(action, j)
		for ax in d.get("axes", []):
			var a := InputEventJoypadMotion.new()
			a.axis = ax[0]
			a.axis_value = ax[1]
			_add(action, a)

static func _add(action: String, e: InputEvent) -> void:
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)

static func label(action: String, gamepad := false) -> String:
	return (PAD_LABELS if gamepad else KEY_LABELS).get(action, action)
