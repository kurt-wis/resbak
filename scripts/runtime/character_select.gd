extends Control

## Demo character select: pick a hero, watch them break dance on a pad, press PLAY to
## spawn into the court playtest. Built in code like court_playtest.gd.
## Keys: Left/Right or A/D to browse, Enter/Space to play. Mouse: click a card, PLAY.
## `-- --capture-preview [--dance-time=SEC]` saves user://resbak-character-select.png and quits.

const PLAYTEST_SCENE := "res://scenes/court_playtest.tscn"

var index: int = 0
var cards: Array[Button] = []
var preview_root: Node3D
var preview_model: Node3D
var preview_player: AnimationPlayer
var name_label: Label
var role_label: Label
var play_button: Button

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("2b2233")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_preview()
	var title := _label("CHOOSE YOUR HERO", 40, Color("ffd34d"))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = 24
	add_child(title)
	name_label = _label("", 56, Color.WHITE)
	name_label.position = Vector2(80, 230)
	add_child(name_label)
	role_label = _label("", 26, Color("e8dccb"))
	role_label.position = Vector2(84, 310)
	add_child(role_label)
	var hint := _label("Left / Right: choose     Enter: play", 18, Color("b9aec8"))
	hint.position = Vector2(84, 360)
	add_child(hint)
	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.add_theme_font_size_override("font_size", 30)
	play_button.position = Vector2(84, 410)
	play_button.size = Vector2(220, 70)
	play_button.pressed.connect(start_game)
	add_child(play_button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.offset_left = -620
	row.offset_right = 620
	row.offset_top = -150
	row.offset_bottom = -40
	add_child(row)
	for i in range(HeroRoster.HEROES.size()):
		var hero: Dictionary = HeroRoster.HEROES[i]
		var card := Button.new()
		card.name = "Card_" + hero["id"]
		card.text = "%s\n%s" % [hero["name"], hero["role"]]
		card.custom_minimum_size = Vector2(180, 110)
		card.toggle_mode = true
		card.add_theme_font_size_override("font_size", 20)
		var style := StyleBoxFlat.new()
		style.bg_color = hero["color"].darkened(0.45)
		style.set_corner_radius_all(10)
		var picked := style.duplicate() as StyleBoxFlat
		picked.bg_color = hero["color"]
		picked.set_border_width_all(4)
		picked.border_color = Color.WHITE
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", picked)
		card.add_theme_stylebox_override("pressed", picked)
		card.add_theme_stylebox_override("hover_pressed", picked)
		card.pressed.connect(select.bind(i))
		row.add_child(card)
		cards.append(card)
	var start := 0
	for i in range(HeroRoster.HEROES.size()):
		if HeroRoster.HEROES[i]["id"] == HeroRoster.selected_id:
			start = i
	select(start)
	if "--capture-preview" in OS.get_cmdline_user_args():
		capture_preview.call_deferred()

func capture_preview() -> void:
	for frame in range(30):
		await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dance-time=") and preview_player:
			preview_player.seek(float(arg.trim_prefix("--dance-time=")), true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://resbak-character-select.png")
	get_tree().quit()

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("18232c"))
	l.add_theme_constant_override("outline_size", 8)
	return l

func _build_preview() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.position = Vector2(560, 70)
	container.size = Vector2(520, 500)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	container.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c9c3e6")
	env.environment.ambient_light_energy = 0.55
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_color = Color("ffe1b8")
	sun.light_energy = 1.1
	vp.add_child(sun)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.8
	disc.height = 0.08
	pad.mesh = disc
	pad.position.y = -0.04
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color("d9b98a")
	pad.material_override = pad_mat
	vp.add_child(pad)
	preview_root = Node3D.new()
	vp.add_child(preview_root)
	# Same high three-quarter angle as the in-game camera, just closer.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.6
	cam.position = Vector3(0, 3.1, 2.7)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.85, 0))

func select(i: int) -> void:
	index = wrapi(i, 0, HeroRoster.HEROES.size())
	var hero: Dictionary = HeroRoster.HEROES[index]
	HeroRoster.selected_id = hero["id"]
	for c in range(cards.size()):
		cards[c].set_pressed_no_signal(c == index)
	name_label.text = hero["name"]
	role_label.text = hero["role"]
	_show_model(hero)

func _show_model(hero: Dictionary) -> void:
	if preview_model:
		preview_model.queue_free()
	preview_model = (load(hero["glb"]) as PackedScene).instantiate() as Node3D
	preview_root.add_child(preview_model)
	var bounds := AABB()
	var found := false
	for node in preview_model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = preview_model.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	if found and bounds.size.y > 0.01:
		var factor: float = 1.8 / bounds.size.y
		preview_model.scale = Vector3.ONE * factor
		preview_model.position.y = -bounds.position.y * factor
	for node in preview_model.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		# BreakDance (tools/build_heroes.py) spins on its own, so the pad stays still.
		var clip := "BreakDance" if ap.has_animation("BreakDance") else "Idle"
		if ap.has_animation(clip):
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			ap.play(clip)
		preview_player = ap
		break

func start_game() -> void:
	get_tree().change_scene_to_file(PLAYTEST_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		select(index - 1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		select(index + 1)
	elif event.is_action_pressed("ui_accept"):
		start_game()
