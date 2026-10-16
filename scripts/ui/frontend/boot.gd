extends FrontScreen

## Boot splash (docs/RESBAK.md § 6): logo 2 s, "Made with Godot" 1 s, note 1 s, skippable
## (any key, click or pad button). Applies saved Settings (display, volumes, key bindings) once.

const LOGO_SECS := 2.0
const GODOT_SECS := 1.0
const NOTE_SECS := 1.0

var phase := 0 ## 0 logo, 1 Godot credit, 2 note, 3 done
var logo: Label
var credit: Label
var note: Label
var _tween: Tween
var _going := false
var auto_advance := true ## tests turn this off

func draws_backdrop() -> bool:
	return false

func build() -> void:
	FE.apply_all()
	var bg := ColorRect.new()
	bg.color = FE.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(center)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(1400, 400)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)
	logo = FE.logo(220)
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.modulate.a = 0.0
	stack.add_child(logo)
	credit = FE.label("Made with Godot", 52, FE.CHALK, HORIZONTAL_ALIGNMENT_CENTER)
	credit.set_anchors_preset(Control.PRESET_FULL_RECT)
	credit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credit.modulate.a = 0.0
	stack.add_child(credit)
	note = FE.label("A game about the Filipino street game Agawan Base.", 40, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	note.set_anchors_preset(Control.PRESET_FULL_RECT)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate.a = 0.0
	stack.add_child(note)
	var hint := FE.label("Pindutin para laktawan", 20, FE.GREY, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -400
	hint.offset_top = -60
	hint.offset_right = -40
	hint.offset_bottom = -20
	content.add_child(hint)
	_run()

func _run() -> void:
	_tween = create_tween()
	_tween.tween_property(logo, "modulate:a", 1.0, 0.35)
	_tween.tween_interval(LOGO_SECS - 0.7)
	_tween.tween_property(logo, "modulate:a", 0.0, 0.35)
	_tween.tween_callback(func(): phase = 1)
	_tween.tween_property(credit, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(GODOT_SECS - 0.4)
	_tween.tween_property(credit, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(func(): phase = 2)
	_tween.tween_property(note, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(NOTE_SECS - 0.4)
	_tween.tween_property(note, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(func():
		phase = 3
		_finish())
	if not auto_advance:
		_tween.pause()

## Total length of the sequence in seconds (2 + 1 + 1).
static func total_secs() -> float:
	return LOGO_SECS + GODOT_SECS + NOTE_SECS

func skip() -> void:
	if _tween:
		_tween.kill()
	phase = 3
	_finish()

func _finish() -> void:
	if _going or not is_inside_tree():
		return
	_going = true
	go("title")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		skip()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip()
