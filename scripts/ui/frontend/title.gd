extends FrontScreen

## Title (docs/RESBAK.md § 6): live court behind the logo, shout line, "Pindutin para maglaro",
## version, Settings, Quit. Any key / click / pad button continues to first-time setup (until
## Save profile.setup_done) or Home. Escape asks "Aalis ka na?".

var prompt: Label
var live: SubViewportContainer
var live_cam: Camera3D
var _t := 0.0
var _going := false

func build() -> void:
	if DisplayServer.get_name() != "headless":
		_build_live_court()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.09, 0.50)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(dim)
	var logo := FE.logo(260)
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.offset_left = -700
	logo.offset_right = 700
	logo.offset_top = 150
	logo.offset_bottom = 480
	content.add_child(logo)
	var shout := FE.shout("Agawan Base! Unahan lang 'yan!", 48, FE.CHALK, FE.INK)
	shout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	shout.offset_left = -700
	shout.offset_right = 700
	shout.offset_top = 480
	shout.offset_bottom = 560
	content.add_child(shout)
	var pb := FE.bi_box("Pindutin para maglaro", "Press any key", 54, FE.GOLD)
	pb.name = "Prompt"
	pb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pb.offset_left = -500
	pb.offset_right = 500
	pb.offset_top = -330
	pb.offset_bottom = -200
	content.add_child(pb)
	prompt = pb.get_node("Fil")
	var ver := FE.label("v" + FE.VERSION, 22, FE.CHALK_DIM)
	ver.name = "Version"
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 40
	ver.offset_top = -60
	ver.offset_right = 600
	ver.offset_bottom = -20
	content.add_child(ver)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.offset_left = -640
	row.offset_right = -40
	row.offset_top = -130
	row.offset_bottom = -30
	row.add_theme_constant_override("separation", 20)
	content.add_child(row)
	var settings := btn("Settings", "Settings", "Settings", Vector2(290, 84), 30)
	var quit := btn("Quit", "Quit", "Quit", Vector2(290, 84), 30)
	row.add_child(settings)
	row.add_child(quit)
	settings.pressed.connect(func():
		FE.back_to = "title"
		go("settings"))
	quit.pressed.connect(_ask_quit)

func _build_live_court() -> void:
	live = SubViewportContainer.new()
	live.stretch = true
	live.set_anchors_preset(Control.PRESET_FULL_RECT)
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(live)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	live.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	MapDressing.add_lighting(world, false)
	var court := (load("res://scenes/barangay_court.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(court)
	MapDressing.dress_court(court)
	live_cam = Camera3D.new()
	live_cam.fov = 40.0
	world.add_child(live_cam)
	live_cam.position = Vector3(0, 17, 21)
	live_cam.look_at_from_position(live_cam.position, Vector3(0, 0, 1))

func _process(delta: float) -> void:
	_t += delta
	if prompt:
		prompt.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 3.2))
	if live_cam:
		var a := sin(_t * 0.18) * 0.30
		live_cam.position = Vector3(sin(a) * 24.0, 15.5 + sin(_t * 0.23) * 1.2, cos(a) * 24.0)
		live_cam.look_at(Vector3(0, 0, 1))

## Continue past the title: first-time setup if the profile has not finished it, else Home.
func proceed() -> void:
	if _going:
		return
	_going = true
	var s := FE.save()
	var done: bool = s != null and bool(s.get_profile().get("setup_done", false))
	go("home" if done else "first_setup")

func _ask_quit() -> void:
	ask("Aalis ka na?", "Leaving?", func(): get_tree().quit())

func on_back() -> void:
	_ask_quit()

func _unhandled_input(event: InputEvent) -> void:
	if dialog:
		super._unhandled_input(event)
		return
	if event.is_action_pressed("ui_cancel"):
		super._unhandled_input(event)
		return
	if event.is_echo() or not event.is_pressed():
		return
	for nav in ["ui_left", "ui_right", "ui_up", "ui_down", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action(nav):
			return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		proceed()

func _gui_input(event: InputEvent) -> void:
	if not dialog and event is InputEventMouseButton and event.pressed:
		proceed()
