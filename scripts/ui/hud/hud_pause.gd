class_name HudPause
extends HudPart

## Escape overlay (docs/RESBAK.md § 7): BUMALIK resumes, UMALIS asks "Aalis ka na?" and leaves
## the match. vs Bots / tutorial also stop the host tick (MatchScene sets host.paused);
## Custom Room keeps running. Fully usable by keyboard and pad (focus + ui_accept).

var dim: ColorRect
var box: VBoxContainer
var title: Label
var resume_button: Button
var leave_button: Button
var confirm_label: Label
var confirm_row: HBoxContainer
var yes_button: Button
var no_button: Button

func _init() -> void:
	visible = false
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.7)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	title = HudStyle.label(box, 72, HORIZONTAL_ALIGNMENT_CENTER, Color.WHITE, 12)
	title.text = "PAUSA"
	title.custom_minimum_size = Vector2(460, 100)
	resume_button = _button("BUMALIK", box)
	leave_button = _button("UMALIS", box)
	confirm_label = HudStyle.label(box, 40, HORIZONTAL_ALIGNMENT_CENTER, HudStyle.GOLD)
	confirm_label.text = "Aalis ka na?"
	confirm_label.custom_minimum_size = Vector2(460, 60)
	confirm_row = HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 20)
	box.add_child(confirm_row)
	yes_button = _button("Oo", confirm_row)
	no_button = _button("Hindi", confirm_row)
	yes_button.custom_minimum_size = Vector2(220, 72)
	no_button.custom_minimum_size = Vector2(220, 72)
	resume_button.pressed.connect(func() -> void: hud.resume_requested.emit())
	leave_button.pressed.connect(_ask_leave)
	yes_button.pressed.connect(func() -> void: hud.leave_requested.emit())
	no_button.pressed.connect(_hide_confirm)
	_hide_confirm()

func _button(text: String, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 36)
	b.custom_minimum_size = Vector2(460, 72)
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	return b

func _layout() -> void:
	var s := sz()
	box.position = Vector2(s.x * 0.5 - 230.0, s.y * 0.5 - 220.0)
	box.size = Vector2(460, 440)

func _ask_leave() -> void:
	confirm_label.visible = true
	confirm_row.visible = true
	if is_inside_tree():
		no_button.grab_focus()

func _hide_confirm() -> void:
	confirm_label.visible = false
	confirm_row.visible = false

func is_open() -> bool:
	return visible

func open(on: bool) -> void:
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_hide_confirm()
	if on and is_inside_tree():
		resume_button.grab_focus()
