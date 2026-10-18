extends HudPart

## Touch controls only produce PlayerInput edges/vectors; gameplay stays on the host tick.
## Visible by default on every device; also accepts mouse gestures for desktop testing.
const STICK_RADIUS := 100.0
const TAG_RADIUS := 92.0
const ACTION_RADIUS := 58.0
var force_touch_controls := false ## deterministic touch-layout checks on desktop
var _stick_finger := -1
var _buttons := {}
var _stick := Vector2.ZERO
var _tag_drag := Vector2.ZERO
var _skill_drags := {}
var _mouse_down := false
var menu_button: Button

func source() -> PlayerInput:
	return hud.input_source as PlayerInput if hud else null

func wanted() -> bool:
	if force_touch_controls or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch-controls"):
		return true
	var save := get_node_or_null("/root/Save")
	return bool(save.get_setting("gameplay", "on_screen_controls")) if save else true

func _ready() -> void:
	super._ready()
	menu_button = FE.button("MENU", "", Vector2(130, 64), 24)
	menu_button.position = Vector2(24, 24)
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	hud.root.add_child(menu_button)
	menu_button.pressed.connect(func(): hud.pause_requested.emit())

func button_ready(button: int) -> bool:
	if button == RB.BTN_TAG:
		return hud.local.can_press_tag()
	if button == RB.BTN_SKILL1 or button == RB.BTN_SKILL2:
		var skill: Skill = hud.local.skills[0 if button == RB.BTN_SKILL1 else 1]
		return hud.host.skills_enabled() and (skill.can_cast() or (skill.can_recast() and hud.local.is_free() and not hud.local.is_disabled() and not hud.local.is_attacking()))
	return hud.local.capturing or hud.local.can_start_capture()

func contains_pad(at: Vector2) -> bool:
	if at.distance_to(stick_centre()) <= STICK_RADIUS * 1.5:
		return true
	for button in action_centres():
		if at.distance_to(action_centres()[button]) <= (TAG_RADIUS if button == RB.BTN_TAG else ACTION_RADIUS):
			return true
	return false

func stick_centre() -> Vector2:
	return Vector2(190, sz().y - 185)

func action_centres() -> Dictionary:
	var s := sz()
	return {RB.BTN_TAG: Vector2(s.x - 170, s.y - 185),
		RB.BTN_SKILL1: Vector2(s.x - 385, s.y - 180),
		RB.BTN_SKILL2: Vector2(s.x - 305, s.y - 330),
		RB.BTN_INTERACT: Vector2(s.x - 140, s.y - 385)}

## Separate release target, safely away from the skill sticks and maximum-range aim.
func cancel_centre() -> Vector2:
	return Vector2(sz().x - 130, sz().y - 555)

func update_cancel(at: Vector2, button: int) -> void:
	var cancelling := at.distance_to(cancel_centre()) <= hud.host.tuning.touch_cancel_radius
	if button == RB.BTN_TAG:
		source().tag_aim_cancelled = cancelling
	else:
		source().touch_skill_cancelled = cancelling

func reset_touches() -> void:
	_stick_finger = -1
	_buttons.clear()
	_stick = Vector2.ZERO
	_tag_drag = Vector2.ZERO
	_skill_drags.clear()
	_mouse_down = false
	if source() and source().touch_active:
		source().clear_touch()
	queue_redraw()

func refresh(_delta: float) -> void:
	visible = wanted() and hud.local != null and hud.host.round_live() and not hud.is_pause_open() and not hud.scoreboard.held
	if not visible or not is_visible_in_tree() or (source() and not source().enabled):
		reset_touches()
	if menu_button:
		menu_button.visible = wanted() and hud.local != null and not hud.is_pause_open() and not hud.scoreboard.held
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_touches()

func _input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if not wanted() or not is_visible_in_tree() or source() == null or not source().enabled:
			return
		if event is InputEventMouseButton:
			if event.button_index != MOUSE_BUTTON_LEFT:
				return
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			if event.pressed and not contains_pad(point):
				return
			if not event.pressed and not _mouse_down:
				return
			_mouse_down = event.pressed
			source().ui_pointer_captured = event.pressed
			source().mouse_controls_active = true
			source().touch_active = true
			var touch := InputEventScreenTouch.new()
			touch.index = -42
			touch.position = event.position
			touch.pressed = event.pressed
			event = touch
		else:
			if not _mouse_down:
				return
			var drag := InputEventScreenDrag.new()
			drag.index = -42
			drag.position = event.position
			event = drag
		get_viewport().set_input_as_handled()
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not wanted() or not is_visible_in_tree() or source() == null or not source().enabled or hud.is_pause_open():
		return
	var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.index == _stick_finger:
				_stick_finger = -1
				_stick = Vector2.ZERO
				source().set_touch_move(_stick)
			if _buttons.has(event.index):
				update_cancel(at, int(_buttons[event.index]))
				if int(_buttons[event.index]) == RB.BTN_TAG:
					source().finish_tag_aim(event.canceled)
				elif int(_buttons[event.index]) in [RB.BTN_SKILL1, RB.BTN_SKILL2]:
					source().finish_touch_skill(event.canceled)
				else:
					source().release_touch(int(_buttons[event.index]))
				_buttons.erase(event.index)
		elif _stick_finger == -1 and at.distance_to(stick_centre()) <= STICK_RADIUS * 1.5:
			_stick_finger = event.index
			_update_stick(at)
		else:
			for button in action_centres():
				var radius := TAG_RADIUS if button == RB.BTN_TAG else ACTION_RADIUS
				if at.distance_to(action_centres()[button]) <= radius and not _buttons.values().has(button):
					if not button_ready(button):
						break
					if button in [RB.BTN_SKILL1, RB.BTN_SKILL2] and source().touch_skill_button != 0:
						break
					_buttons[event.index] = button
					if button == RB.BTN_TAG:
						_tag_drag = Vector2.ZERO
						source().touch_active = true
						source().begin_tag_aim()
					elif button in [RB.BTN_SKILL1, RB.BTN_SKILL2]:
						_skill_drags[button] = Vector2.ZERO
						source().begin_touch_skill(button)
					else:
						source().press_touch(button)
					break
			if not _buttons.has(event.index):
				source().select_touch_target(hud.local, hud.host, event.position)
	elif event.index == _stick_finger:
		_update_stick(at)
	elif _buttons.get(event.index, 0) == RB.BTN_TAG:
		_tag_drag = at - action_centres()[RB.BTN_TAG]
		source().drag_tag_aim(at - action_centres()[RB.BTN_TAG], hud.host.tuning)
		update_cancel(at, RB.BTN_TAG)
	elif _buttons.get(event.index, 0) in [RB.BTN_SKILL1, RB.BTN_SKILL2]:
		var button: int = _buttons[event.index]
		_skill_drags[button] = at - action_centres()[button]
		source().drag_touch_skill(_skill_drags[button], hud.host.tuning)
		update_cancel(at, button)
	queue_redraw()

func _update_stick(at: Vector2) -> void:
	_stick = ((at - stick_centre()) / STICK_RADIUS).limit_length()
	source().set_touch_move(_stick)

func _draw() -> void:
	if not visible:
		return
	var centre := stick_centre()
	draw_circle(centre + Vector2(0, 5), STICK_RADIUS + 5, Color(0, 0, 0, 0.18))
	draw_circle(centre, STICK_RADIUS, Color(0.06, 0.08, 0.12, 0.72))
	draw_arc(centre, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.6), 3, true)
	draw_circle(centre + _stick * STICK_RADIUS * 0.65, 40, Color(0.72, 0.79, 0.86, 0.95))
	draw_arc(centre, STICK_RADIUS - 12, 0, TAU, 48, Color(1, 1, 1, 0.08), 1, true)
	var labels := {RB.BTN_TAG: "TAG", RB.BTN_SKILL1: "S1", RB.BTN_SKILL2: "S2", RB.BTN_INTERACT: "BASE"}
	for button in action_centres():
		var at: Vector2 = action_centres()[button]
		var radius := TAG_RADIUS if button == RB.BTN_TAG else ACTION_RADIUS
		var col := Color("ef4444") if button == RB.BTN_TAG else hud.team_color(hud.local.team)
		if button in [RB.BTN_SKILL1, RB.BTN_SKILL2]:
			col = hud.local.data.color.lerp(Color.WHITE, 0.15)
		var ready := button_ready(button)
		var held: bool = source() and ((button == RB.BTN_TAG and source().tag_aiming) or source().touch_skill_button == button)
		var accent := Color(col, 1.0 if ready else 0.3)
		draw_circle(at + Vector2(0, 5), radius + 4, Color(0, 0, 0, 0.22))
		draw_circle(at, radius, Color(0.07, 0.09, 0.13, 0.92))
		draw_circle(at, radius - 5, Color(col, 0.45 if held else (0.2 if ready else 0.05)))
		draw_arc(at, radius, 0, TAU, 64, accent, 4 if held else 2, true)
		draw_arc(at, radius - 8, PI, PI * 1.8, 32, Color(1, 1, 1, 0.16), 2, true)
		var text: String = labels[button]
		if button == RB.BTN_TAG and source() and source().tag_aiming:
			text = "CANCEL" if source().tag_aim_cancelled else "AIM"
			draw_arc(at, hud.host.tuning.skill_aim_pad_radius, 0, TAU, 64, Color(1, 1, 1, 0.15), 2, true)
			var tip := at + _tag_drag.limit_length(hud.host.tuning.skill_aim_pad_radius)
			draw_line(at, tip, Color.WHITE, 3, true)
			draw_circle(tip, 12, Color.WHITE)
		if button in [RB.BTN_SKILL1, RB.BTN_SKILL2]:
			var skill: Skill = hud.local.skills[0 if button == RB.BTN_SKILL1 else 1]
			var config := SkillAim.profile(skill)
			var icon_color := Color(1, 1, 1, 0.9 if ready else 0.25)
			text = ""
			if skill.cd_ticks > 0 and not skill.active:
				text = str(ceili(RB.seconds(skill.cd_ticks)))
				icon_color.a = 0.2
				draw_arc(at, radius - 6, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - skill.cd_fraction()), 48, Color.WHITE, 5, true)
			if skill.active:
				text = "STOP" if skill.can_recast() else "ACTIVE"
				icon_color.a = 0.25
			if skill.warded():
				text = "GUARD"
				icon_color.a = 0.25
			SkillAim.draw_icon(self, str(config.icon), at, 23.0, icon_color)
			var name_text := skill.skill_name()
			var font := HudStyle.font()
			var width := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(font, at + Vector2(-width * 0.5, -radius - 14), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
			if source() and source().touch_skill_button == button and config.mode != "self" and not skill.active:
				text = "CANCEL" if source().touch_skill_cancelled else ""
				var offset: Vector2 = _skill_drags.get(button, Vector2.ZERO)
				var tip := at + offset.limit_length(hud.host.tuning.skill_aim_pad_radius)
				draw_arc(at, hud.host.tuning.skill_aim_pad_radius, 0, TAU, 64, Color(1, 1, 1, 0.15), 2, true)
				draw_line(at, tip, Color.WHITE, 3, true)
				draw_circle(tip, 12, Color.WHITE)

		var font := HudStyle.font()
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(font, at + Vector2(-width * 0.5, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)

	if source() and source().touch_skill_button != 0:
		var skill: Skill = hud.local.skills[0 if source().touch_skill_button == RB.BTN_SKILL1 else 1]
		var config := SkillAim.profile(skill)
		var hint: String = config.hint
		if source().touch_skill_cancelled:
			hint = "Release on × to cancel / move away to keep aiming"
		elif skill.active:
			hint = "Release to stop " + skill.skill_name()
		elif config.mode == "point":
			hint += " | Drag to aim · release to cast"
		var panel := Rect2(sz().x * 0.5 - 450, sz().y - 245, 900, 60)
		HudStyle.panel(self, panel, hud.local.data.color, Color(0.05, 0.06, 0.09, 0.85), 12, 2)
		HudStyle.text_in(self, hint, panel, 22, Color.WHITE, 8)

	if source() and (source().tag_aiming or source().touch_skill_button != 0):
		var cancel := cancel_centre()
		var cancelling: bool = source().tag_aim_cancelled if source().tag_aiming else source().touch_skill_cancelled
		var radius := hud.host.tuning.touch_cancel_radius
		var tint := Color("ff6b63") if cancelling else Color("bac4d2")
		draw_circle(cancel + Vector2(0, 4), radius + 3, Color(0, 0, 0, 0.2))
		draw_circle(cancel, radius, Color("7f252c") if cancelling else Color(0.07, 0.09, 0.13, 0.94))
		draw_arc(cancel, radius, 0, TAU, 48, tint, 4 if cancelling else 2, true)
		draw_line(cancel - Vector2(12, 12), cancel + Vector2(12, 12), tint, 4, true)
		draw_line(cancel + Vector2(-12, 12), cancel + Vector2(12, -12), tint, 4, true)
		HudStyle.text_in(self, "RELEASE TO CANCEL" if cancelling else "CANCEL", Rect2(cancel + Vector2(-110, radius + 8), Vector2(220, 30)), 20, tint, 4)
