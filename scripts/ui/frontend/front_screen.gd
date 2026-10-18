class_name FrontScreen
extends Control

## Base for every front-end screen (docs/RESBAK.md § 6 Navigation): full-rect 1920x1080 canvas,
## chalk backdrop, shared theme, a `content` layer, first-focus handling, Escape/B/Circle back,
## and a Hindi-by-default confirm dialog. Subclasses override build(), first_focus(), on_back().
## `--shot=<file.png>` (user arg) saves the screen after a few frames and quits (dev aid).

var content: Control
var backdrop: ChalkBackdrop
var buttons := {} ## name -> Button, for tests and focus helpers
var dialog: Control
var _dialog_prev_focus: Control
var _frozen: Array = []
var navigate := true ## tests turn this off; go() then only records last_go
var last_go := ""

signal navigated(target: String)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = FE.get_theme()
	mouse_filter = Control.MOUSE_FILTER_PASS
	if draws_backdrop():
		backdrop = ChalkBackdrop.new()
		backdrop.name = "Backdrop"
		add_child(backdrop)
	content = Control.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	build()
	_focus_first.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot.call_deferred(a.trim_prefix("--shot="))

## Route to another screen ("home", "settings", ...) through the chalk wipe.
func go(screen: String) -> void:
	last_go = screen
	navigated.emit(screen)
	if navigate:
		FE.go(self, screen)

## Run a callable at the wipe midpoint (e.g. Session.start_match); `label` is recorded.
func go_call(label: String, action: Callable) -> void:
	last_go = label
	navigated.emit(label)
	if navigate:
		FE.go_call(self, action)

func draws_backdrop() -> bool:
	return true

func build() -> void:
	pass

func first_focus() -> Control:
	return null

func on_back() -> void:
	pass

func _focus_first() -> void:
	if not is_inside_tree():
		return
	var f := first_focus()
	if f and f.is_inside_tree() and f.focus_mode != Control.FOCUS_NONE:
		f.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if dialog:
			close_dialog()
		else:
			on_back()

func btn(key: String, fil: String, en := "", size := Vector2(300, 72), fsize := 30, greyed := false, primary := false) -> Button:
	var b := FE.button(fil, en, size, fsize, greyed, primary)
	b.name = key
	buttons[key] = b
	return b

# ---- dialog -----------------------------------------------------------------------------
## Modal Oo / Hindi dialog; Hindi is focused (spec: dialogs Hindi). Escape/B closes (= Hindi).
func ask(fil: String, en: String, on_yes: Callable, sub := "", timeout := 0.0, on_timeout := Callable()) -> Control:
	if dialog:
		close_dialog()
	_dialog_prev_focus = get_viewport().gui_get_focus_owner()
	_freeze(content, true)
	dialog = Control.new()
	dialog.name = "Dialog"
	dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(center)
	var p := FE.panel(FE.INK2, FE.CHALK, 3, 22)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.custom_minimum_size = Vector2(640, 0)
	p.add_child(v)
	var title := FE.bi_box(fil, en, 44)
	title.name = "Title"
	v.add_child(title)
	if sub != "":
		var s := FE.label(sub, 22, FE.CHALK_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		s.name = "Sub"
		v.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	v.add_child(row)
	var yes := FE.button("Oo", "Yes", Vector2(220, 72), 32)
	yes.name = "Yes"
	var no := FE.button("Hindi", "No", Vector2(220, 72), 32)
	no.name = "No"
	row.add_child(yes)
	row.add_child(no)
	add_child(dialog)
	yes.pressed.connect(func():
		close_dialog()
		on_yes.call())
	no.pressed.connect(func():
		close_dialog()
		if on_timeout.is_valid():
			on_timeout.call())
	if timeout > 0.0:
		var tw := dialog.create_tween()
		tw.tween_interval(timeout)
		tw.tween_callback(func():
			close_dialog()
			if on_timeout.is_valid():
				on_timeout.call())
	no.grab_focus()
	return dialog

func close_dialog() -> void:
	if dialog == null:
		return
	var d := dialog
	dialog = null
	d.queue_free()
	_freeze(content, false)
	if _dialog_prev_focus and is_instance_valid(_dialog_prev_focus) and _dialog_prev_focus.is_inside_tree():
		_dialog_prev_focus.grab_focus()
	else:
		_focus_first()

func _freeze(root: Node, on: bool) -> void:
	if on:
		_frozen.clear()
		for c in root.find_children("*", "Control", true, false):
			if (c as Control).focus_mode != Control.FOCUS_NONE:
				_frozen.append([c, (c as Control).focus_mode])
				(c as Control).focus_mode = Control.FOCUS_NONE
	else:
		for pair in _frozen:
			if is_instance_valid(pair[0]):
				(pair[0] as Control).focus_mode = pair[1]
		_frozen.clear()

func _shot(path: String) -> void:
	for i in range(45):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
