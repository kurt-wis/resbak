extends Node3D

const Hamog := preload("res://scripts/runtime/batang_hamog.gd")

var player: CharacterBody3D
var visual: Node3D
var model: Node3D
var camera: Camera3D
var animator: AnimationPlayer
var touch_direction := Vector2.ZERO
var speed := 5.0
var overview := false
var show_full_roof := false
var roof_paints: Array[ShaderMaterial] = []
var camera_focus := Vector3.ZERO

# legacy clip vars kept for compat (controller owns real clips)
var idle_clip := ""
var walk_clip := ""
var run_clip := ""
var base_cam_size := 8.5
var hero_id := "hamog" ## from HeroRoster.selected_id or --hero=<id>; hamog = skills prototype

func block(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _ready() -> void:
	var vp = get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_4X
	RenderingServer.set_default_clear_color(Color("d0c6b7"))
	var light := DirectionalLight3D.new()
	light.name = "WarmAfternoonSun"
	light.rotation_degrees = Vector3(-38,-38,0)
	light.light_color = Color("ffe1b8")
	light.light_energy = 0.80
	light.shadow_enabled = true
	light.shadow_opacity = 0.68
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 65.0
	light.directional_shadow_blend_splits = true
	light.shadow_bias = 1.0
	light.shadow_normal_bias = 3.0
	add_child(light)
	if "--no-shadows" in OS.get_cmdline_user_args():
		light.shadow_enabled = false
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("9faad9")
	world.environment.ambient_light_energy = 0.16
	world.environment.adjustment_enabled = true
	world.environment.adjustment_contrast = 1.06
	world.environment.adjustment_saturation = 0.95
	add_child(world)
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	add_child(court)
	style_purple_tricycle(court)
	add_prop_contact_shadows(court)
	collect_roof_materials(court)
	hero_id = HeroRoster.selected_id
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hero="):
			hero_id = arg.trim_prefix("--hero=")
	if hero_id == "" or hero_id == "hamog":
		hero_id = "hamog"
		player = Hamog.new()
		player.name = "BatangHamogPlayer"
	else:
		player = HeroController.new()
		player.hero_id = hero_id
		player.name = "HeroPlayer"
	player.position = Vector3(-10,0.2,2)
	add_child(player)
	# Hamog._ready runs synchronously on add_child; link visual/model now.
	visual = player.get_node_or_null("CharacterVisual")
	model = visual.get_child(0) if visual and visual.get_child_count() > 0 else null
	if model:
		apply_illustrated_materials(model)
	animator = null
	if model:
		for node in model.find_children("*", "AnimationPlayer", true, false):
			animator = node as AnimationPlayer
			break
	setup_animator()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = base_cam_size
	camera.current = true
	camera.far = 120.0
	camera_focus = player.position + Vector3(0,0.65,0)
	camera.position = camera_focus + Vector3(0,11,7.5)
	add_child(camera)
	add_illustrated_edges()
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	var hero_name: String = HeroRoster.get_hero(hero_id).get("name", "Batang Hamog")
	if hero_id == "hamog":
		label.text = "RESBAK  /  BARANGAY COURT  /  %s
WASD/arrows: move  Shift: HARUROT  Ctrl/C: LUSOT  E/LMB: tag  M: map  Esc: heroes" % hero_name
	else:
		label.text = "RESBAK  /  BARANGAY COURT  /  %s
WASD/arrows: run  hold Alt: walk  M: map  Esc: heroes" % hero_name
	label.position = Vector2(20,15)
	label.add_theme_color_override("font_outline_color",Color("18232c"))
	label.add_theme_constant_override("outline_size",6)
	label.add_theme_color_override("font_color",Color("ffffff"))
	layer.add_child(label)
	var controls := Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(controls)
	for data in [["UP",Vector2(0,-1),Vector2(100,-180)],["DOWN",Vector2(0,1),Vector2(100,-90)],["LEFT",Vector2(-1,0),Vector2(15,-90)],["RIGHT",Vector2(1,0),Vector2(185,-90)]]:
		var button := Button.new()
		button.text = data[0]
		button.anchor_top = 1
		button.anchor_bottom = 1
		button.position = data[2]
		button.size = Vector2(80,75)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		var direction: Vector2 = data[1]
		button.button_down.connect(func(): touch_direction = direction)
		button.button_up.connect(func(): touch_direction = Vector2.ZERO)
		controls.add_child(button)
	# skill buttons (touch)
	var dash_btn := Button.new()
	dash_btn.text = "DASH"
	dash_btn.anchor_top = 1
	dash_btn.anchor_bottom = 1
	dash_btn.position = Vector2(280,-90)
	dash_btn.size = Vector2(90,75)
	dash_btn.pressed.connect(func(): if player and player.has_method("try_harurot"): player.try_harurot())
	controls.add_child(dash_btn)
	var lusot_btn := Button.new()
	lusot_btn.text = "LUSOT"
	lusot_btn.anchor_top = 1
	lusot_btn.anchor_bottom = 1
	lusot_btn.position = Vector2(380,-90)
	lusot_btn.size = Vector2(90,75)
	lusot_btn.pressed.connect(func(): if player and player.has_method("try_lusot"): player.try_lusot())
	controls.add_child(lusot_btn)
	dash_btn.visible = hero_id == "hamog"
	lusot_btn.visible = hero_id == "hamog"
	var map_button := Button.new()
	map_button.text = "MAP / FOLLOW"
	map_button.anchor_left = 1
	map_button.anchor_right = 1
	map_button.offset_left = -190
	map_button.offset_right = -20
	map_button.offset_top = 20
	map_button.offset_bottom = 65
	map_button.pressed.connect(func(): overview = not overview)
	layer.add_child(map_button)
	if "--overview" in OS.get_cmdline_user_args():
		overview = true
	if "--roof" in OS.get_cmdline_user_args():
		show_full_roof = true
	if "--capture-preview" in OS.get_cmdline_user_args():
		capture_preview.call_deferred()

func setup_animator() -> void:
	# Clips owned by BatangHamogController; mirror names here for legacy compat.
	if player and "idle_clip" in player:
		idle_clip = player.idle_clip
		walk_clip = player.walk_clip
		run_clip = player.run_clip

func _play_clip(_name: String, _spd: float = 1.0) -> void:
	pass # controller owns animation

func _physics_process(delta: float) -> void:
	if player == null or camera == null:
		return
	if player and "external_move" in player:
		player.external_move = touch_direction
	if overview:
		camera.size = 31
		camera.position = Vector3(0,34,24)
		camera.look_at(Vector3(0,0,1))
	else:
		camera.size = base_cam_size
		var input_v := touch_direction
		if player and "external_move" in player:
			input_v = touch_direction
		var target := player.position + Vector3(input_v.x*0.55,0.65,input_v.y*0.55)
		target.x = clampf(target.x,-15.0,15.0)
		target.z = clampf(target.z,-7.5,13.0)
		camera_focus = camera_focus.lerp(target,1.0-exp(-9.0*delta))
		camera.position = camera_focus + Vector3(0,11,7.5)
		camera.look_at(camera_focus)
	update_roof_cutaway()

func apply_illustrated_materials(m: Node3D) -> void:
	var outline := ShaderMaterial.new()
	outline.shader = load("res://shaders/character_outline.gdshader")
	for instance in m.find_children("*", "MeshInstance3D", true, false):
		instance.mesh = instance.mesh.duplicate()
		instance.mesh.resource_name = "BatangHamogGeometry"
		for surface in range(instance.mesh.get_surface_count()):
			var source = instance.get_active_material(surface)
			if source is StandardMaterial3D:
				var toon := ShaderMaterial.new()
				toon.resource_name = "BatangHamogPaintedMaterial"
				toon.shader = load("res://shaders/character_toon.gdshader")
				toon.set_shader_parameter("base_texture", source.albedo_texture)
				toon.set_shader_parameter("base_color", source.albedo_color)
				toon.next_pass = null
				instance.set_surface_override_material(surface, toon)

func capture_preview() -> void:
	for frame in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var filename := "resbak-roof.png" if show_full_roof else ("resbak-cleaned-map.png" if overview else "resbak-cleaned-gameplay.png")
	var preview_path := "user://" + filename
	get_viewport().get_texture().get_image().save_png(preview_path)
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		overview = not overview
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		show_full_roof = not show_full_roof
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/character_select.tscn")

func add_illustrated_edges() -> void:
	var frame := MeshInstance3D.new()
	frame.name = "IllustratedInkEdges"
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	frame.mesh = quad
	frame.extra_cull_margin = 16384
	frame.position.z = -1
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/illustrated_edges.gdshader")
	material.render_priority = 127
	frame.material_override = material
	camera.add_child(frame)

func style_purple_tricycle(court: Node3D) -> void:
	var tricycle := court.get_node("StreetDetails/PurpleStreetTricycle")
	for mesh in tricycle.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original:
				var paint := ShaderMaterial.new()
				paint.resource_name = "PurpleTricyclePaint"
				paint.shader = load("res://shaders/purple_vehicle.gdshader")
				paint.set_shader_parameter("paint_texture", original.albedo_texture)
				mesh.set_surface_override_material(surface,paint)

func add_prop_contact_shadows(court: Node3D) -> void:
	var paint := ShaderMaterial.new()
	paint.shader = load("res://shaders/painted_contact_shadow.gdshader")
	paint.render_priority = 90
	for group_name in ["CourtProps", "StreetDetails"]:
		var group := court.get_node(group_name)
		for prop in group.get_children():
			if prop is not Node3D or prop is MeshInstance3D or prop is StaticBody3D:
				continue
			var meshes := prop.find_children("*", "MeshInstance3D", true, false)
			if meshes.is_empty():
				continue
			var bounds := AABB()
			var first := true
			for mesh in meshes:
				var local: AABB = prop.transform * mesh.transform * mesh.get_aabb()
				bounds = local if first else bounds.merge(local)
				first = false
			var shadow := MeshInstance3D.new()
			shadow.name = String(prop.name) + "ContactShadow"
			var plane := PlaneMesh.new()
			plane.size = Vector2(maxf(bounds.size.x,0.3)*1.15,maxf(bounds.size.z,0.3)*1.1)
			shadow.mesh = plane
			shadow.position = Vector3(bounds.get_center().x,0.036,bounds.get_center().z)
			shadow.material_override = paint
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(shadow)

func collect_roof_materials(court: Node3D) -> void:
	if not court.has_node("CourtRoof"): return
	for mesh in court.get_node("CourtRoof").find_children("*", "MeshInstance3D", true, false):
		var material := mesh.get_active_material(0) as ShaderMaterial
		if material and not roof_paints.has(material):
			roof_paints.append(material)

func update_roof_cutaway() -> void:
	var vp := get_viewport()
	if vp == null or camera == null or player == null:
		return
	var screen_size := vp.get_visible_rect().size
	var screen_position := camera.unproject_position(player.position + Vector3(0,0.8,0))
	var focus := screen_position / screen_size
	if overview:
		focus = Vector2(0.5,0.5)
	for material in roof_paints:
		material.set_shader_parameter("cutaway",not show_full_roof)
		material.set_shader_parameter("focus_uv",focus)
		material.set_shader_parameter("cutaway_radius",0.65 if overview else 0.92)
