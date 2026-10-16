extends Node3D

@export_enum("Left base", "Right base") var player_team_side := 0
# Assign an actual enemy base node when the team/base feature is connected.
@export var enemy_base_path: NodePath

var player: CharacterBody3D
var visual: Node3D
var camera: Camera3D
var animator: AnimationPlayer
var touch_direction := Vector2.ZERO
var movement_active := false
var movement_reference_yaw := 0.0
var speed := 8.0
var previous_camera_yaw := 0.0
var overview := false
var show_full_roof := false
var roof_paints: Array[ShaderMaterial] = []
var camera_focus := Vector3.ZERO
var camera_yaw := 0.0
var camera_target_yaw := 0.0
var flip_active := false
var flip_elapsed := 0.0
var flip_camera_start := 0.0
var flip_character_start := 0.0
var flip_character_target := 0.0
var last_move_input := Vector2.ZERO
const FLIP_DURATION := 0.65
var camera_pitch := deg_to_rad(-35.264)
var camera_distance := 20.0
var camera_arm_distance := 20.0
var camera_view_size := 10.2
var camera_base_size := 10.2
var camera_swivel := 0.0
var camera_motion_lead := Vector3.ZERO
const COURTSIDE_ANGLE := 45.0
var camera_probe := SphereShape3D.new()
var camera_finish: ShaderMaterial
const CAMERA_LEFT_OFFSET := 0.0
const MOUSE_SENSITIVITY := 0.0025
var reference_camera: Dictionary
var map_scale := Vector3.ONE

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
	get_viewport().msaa_3d = Viewport.MSAA_4X
	RenderingServer.set_default_clear_color(Color("cad9d9"))
	var light := DirectionalLight3D.new()
	light.name = "WarmAfternoonSun"
	light.rotation_degrees = Vector3(-48,-32,0)
	light.light_color = Color("fff0d4")
	light.light_energy = 0.96
	light.shadow_enabled = true
	light.shadow_opacity = 0.76
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 65.0
	light.directional_shadow_blend_splits = true
	light.shadow_bias = 1.5
	light.shadow_normal_bias = 1.2
	add_child(light)
	if "--no-shadows" in OS.get_cmdline_user_args():
		light.shadow_enabled = false
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("9eb9d0")
	world.environment.ambient_light_energy = 0.29
	world.environment.adjustment_enabled = true
	world.environment.adjustment_contrast = 1.05
	world.environment.adjustment_saturation = 1.02
	add_child(world)
	var ambience := AudioStreamPlayer.new()
	ambience.name = "BarangayDaylightAmbience"
	var ambience_stream := AudioStreamWAV.load_from_file("res://assets/audio/barangay_daylight.wav")
	if ambience_stream:
		ambience_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambience_stream.loop_end = int(ambience_stream.get_length()*ambience_stream.mix_rate)
		ambience.stream = ambience_stream
		ambience.volume_db = -25.0
		add_child(ambience)
		ambience.play()
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	add_child(court)
	reference_camera=court.get_meta("reference_camera",{})
	map_scale=court.scale
	style_purple_tricycle(court)
	add_prop_contact_shadows(court)
	collect_roof_materials(court)
	player = CharacterBody3D.new()
	player.name = "BatangHamogPlayer"
	player.floor_snap_length = 0.35
	player.floor_constant_speed = true
	player.position = Vector3(-10.*map_scale.x,1.7,2.*map_scale.z)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	collision.shape = capsule
	collision.position.y = 0.8
	player.add_child(collision)
	visual = Node3D.new()
	visual.name = "CharacterVisual"
	player.add_child(visual)
	add_child(player)
	var model = load("res://assets/characters/batang_hamog.glb").instantiate()
	model.name = "BatangHamog"
	visual.add_child(model)
	apply_illustrated_materials(model)
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		if not found:
			bounds = box
			found = true
		else:
			bounds = bounds.merge(box)
	if found and bounds.size.y > 0.01:
		var factor: float = 1.8 / bounds.size.y
		model.scale = Vector3.ONE * factor
		model.position.y = -bounds.position.y * factor
	animator = model.find_child("*", true, false) as AnimationPlayer
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animator = node
		break
	if animator:
		for clip in animator.get_animation_list():
			if "Running" in clip:
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animator.play(clip)
				animator.pause()
				break
	camera = Camera3D.new()
	camera.name = "DynamicIsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_view_size
	camera.fov = 52.0
	camera.near = 0.08
	camera.current = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.far = 120.0
	camera_probe.radius = 0.18
	camera_focus = player.position + Vector3(0,1.4,0)
	add_child(camera)
	face_enemy_base()
	update_follow_camera(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_illustrated_edges()
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "RESBAK  /  BARANGAY COURT\nJoystick: move   FLIP: change court end   M: map"
	label.position = Vector2(20,15)
	label.add_theme_color_override("font_outline_color",Color("18232c"))
	label.add_theme_constant_override("outline_size",6)
	label.add_theme_color_override("font_color",Color("ffffff"))
	layer.add_child(label)
	var controls := Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(controls)
	var joystick := Control.new()
	joystick.name = "MovementJoystick"
	joystick.set_script(load("res://scripts/mobile_joystick.gd"))
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 24
	joystick.offset_right = 224
	joystick.offset_top = -224
	joystick.offset_bottom = -24
	joystick.direction_changed.connect(func(direction: Vector2): touch_direction = direction)
	controls.add_child(joystick)
	var map_button := Button.new()
	map_button.text = "MAP / FOLLOW"
	map_button.anchor_left = 1.0
	map_button.anchor_right = 1.0
	map_button.position = Vector2(-190,20)
	map_button.size = Vector2(170,45)
	map_button.pressed.connect(toggle_overview)
	layer.add_child(map_button)
	var flip_button := Button.new()
	flip_button.name = "FlipCameraButton"
	flip_button.text = "FLIP CAMERA"
	flip_button.anchor_left = 1.0
	flip_button.anchor_right = 1.0
	flip_button.anchor_top = 1.0
	flip_button.anchor_bottom = 1.0
	flip_button.position = Vector2(-210,-110)
	flip_button.size = Vector2(180,70)
	flip_button.pressed.connect(flip_camera)
	layer.add_child(flip_button)
	if "--overview" in OS.get_cmdline_user_args():
		overview = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if "--roof" in OS.get_cmdline_user_args():
		show_full_roof = true
	if "--capture-preview" in OS.get_cmdline_user_args():
		capture_preview.call_deferred()

func _physics_process(delta: float) -> void:
	previous_camera_yaw = camera_yaw
	var turning_with_camera := flip_active and not overview
	if turning_with_camera:
		flip_elapsed = minf(flip_elapsed+delta,FLIP_DURATION)
		var progress := smoothstep(0.0,1.0,flip_elapsed/FLIP_DURATION)
		camera_yaw = lerp_angle(flip_camera_start,camera_target_yaw,progress)
		visual.rotation.y = lerp_angle(flip_character_start,flip_character_target,progress)
		# Rotate a held joystick gesture with the new view instead of leaving the body behind.
		movement_reference_yaw = camera_view_yaw()
		if flip_elapsed >= FLIP_DURATION:
			flip_active = false
	var input := touch_direction
	input.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	input.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	input = input.limit_length()
	last_move_input = input
	var move_speed := movement_speed(input.length())
	var direction := Vector3(input.x,0,input.y).normalized()
	if not overview:
		# Each new gesture uses the current court view.
		if input.length() > 0.01 and not movement_active:
			movement_reference_yaw = camera_view_yaw()
		direction = Basis(Vector3.UP,movement_reference_yaw) * direction
	movement_active = input.length() > 0.01
	var horizontal := Vector3(player.velocity.x,0,player.velocity.z)
	var acceleration := 60.0 if move_speed < 0.01 else 45.0
	horizontal = horizontal.move_toward(direction*move_speed,acceleration*delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	if not player.is_on_floor():
		player.velocity.y -= 20 * delta
	else:
		player.velocity.y = 0
	player.move_and_slide()
	var actual_speed := Vector2(player.velocity.x,player.velocity.z).length()
	if input.length() > 0.01 and not turning_with_camera:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),1.0-exp(-15.0*delta))
	if animator:
		if actual_speed > 0.08:
			animator.speed_scale = clampf(actual_speed/6.0,0.25,1.35)
			if not animator.is_playing(): animator.play()
		else:
			animator.pause()

func movement_speed(strength: float) -> float:
	if strength <= 0.35:
		return 3.2*strength/0.35
	return lerpf(3.2,speed,smoothstep(0.35,0.7,strength))

func _process(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player): return
	if overview:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = reference_camera.get("fov",46.0)
		camera.position = reference_camera.get("position",Vector3(0,31,27))
		camera.look_at(reference_camera.get("target",Vector3(0,1.5,3.8)))
	else:
		update_follow_camera(delta)
	update_roof_cutaway()

func set_player_team_side(side: int) -> void:
	player_team_side = clampi(side,0,1)
	if is_instance_valid(player) and is_instance_valid(camera):
		face_enemy_base()
		update_follow_camera(0.0)

func face_enemy_base() -> void:
	# The default base sides are the two hoop ends, along the court's length.
	var enemy_direction := Vector3.RIGHT if player_team_side == 0 else Vector3.LEFT
	var enemy_base := get_node_or_null(enemy_base_path) as Node3D if not enemy_base_path.is_empty() else null
	if enemy_base != null:
		var toward_base: Vector3 = enemy_base.global_position-player.global_position
		toward_base.y = 0.0
		if toward_base.length_squared() > 0.01:
			enemy_direction = toward_base.normalized()
	camera_yaw = atan2(-enemy_direction.x,-enemy_direction.z)
	camera_target_yaw = camera_yaw
	previous_camera_yaw = camera_yaw
	visual.rotation.y = camera_yaw+PI
	movement_reference_yaw = camera_view_yaw()
	movement_active = false
	flip_active = false
	camera_focus = player.position+Vector3(0,1.4,0)+enemy_direction*1.5

func flip_camera() -> void:
	if overview:
		return
	flip_camera_start = camera_yaw
	flip_character_start = visual.rotation.y
	camera_target_yaw = wrapf(camera_target_yaw+PI,-PI,PI)
	flip_character_target = camera_target_yaw+PI
	if last_move_input.length() > 0.01:
		flip_character_target = camera_target_yaw+deg_to_rad(COURTSIDE_ANGLE)+camera_swivel+atan2(last_move_input.x,last_move_input.y)
	flip_elapsed = 0.0
	flip_active = true

func toggle_overview() -> void:
	overview = not overview
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	movement_active = false
	if not overview:
		camera_focus = player.position + Vector3(0,1.4,0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if overview:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_base_size = maxf(8.0,camera_base_size-0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_base_size = minf(15.0,camera_base_size+0.5)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pitch = clampf(camera_pitch-event.relative.y*MOUSE_SENSITIVITY,deg_to_rad(-45),deg_to_rad(-30))

func camera_clear_position(from: Vector3, to: Vector3) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_probe
	query.transform = Transform3D(Basis.IDENTITY,from)
	query.motion = to-from
	query.margin = 0.04
	query.exclude = [player.get_rid()]
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return from+query.motion*fractions[0]

func camera_view_yaw() -> float:
	return camera_yaw+deg_to_rad(COURTSIDE_ANGLE)+camera_swivel

func update_follow_camera(delta: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_view_size
	camera.fov = 52.0
	var horizontal_velocity := Vector3(player.velocity.x,0,player.velocity.z)
	var run_amount := clampf(horizontal_velocity.length()/8.0,0.0,1.0)
	var desired_distance := camera_distance
	var desired_size := camera_base_size+1.0*run_amount
	var court_right := Basis(Vector3.UP,camera_yaw)*Vector3.RIGHT
	var draw_position := player.global_position if delta == 0.0 else player.get_global_transform_interpolated().origin
	var draw_yaw := camera_yaw if delta == 0.0 else lerp_angle(previous_camera_yaw,camera_yaw,Engine.get_physics_interpolation_fraction())
	var lateral_position := draw_position.dot(court_right)
	var desired_swivel := deg_to_rad(6.0)*clampf(lateral_position/12.0,-1.0,1.0)
	if flip_active:
		desired_swivel = 0.0
	var desired_lead := horizontal_velocity*0.18
	if delta == 0.0:
		camera_arm_distance = desired_distance
		camera_view_size = desired_size
		camera_swivel = desired_swivel
		camera_motion_lead = desired_lead
	else:
		camera_arm_distance = lerpf(camera_arm_distance,desired_distance,1.0-exp(-3.0*delta))
		camera_view_size = lerpf(camera_view_size,desired_size,1.0-exp(-2.5*delta))
		camera_swivel = lerp_angle(camera_swivel,desired_swivel,1.0-exp(-2.0*delta))
		camera_motion_lead = camera_motion_lead.lerp(desired_lead,1.0-exp(-4.0*delta))
	# Isometric court framing; restrained swivel follows court position, never a full joystick-driven orbit.
	var ahead := Basis(Vector3.UP,draw_yaw)*Vector3(0,0,-1.4)
	var target := draw_position+Vector3(0,1.4,0)+ahead+camera_motion_lead
	camera_focus = target if delta == 0.0 else camera_focus.lerp(target,1.0-exp(-8.0*delta))
	camera.size = camera_view_size
	var orbit := Basis.from_euler(Vector3(camera_pitch,draw_yaw+deg_to_rad(COURTSIDE_ANGLE)+camera_swivel,0))
	# Orthographic zoom is camera.size; keep the lens above scenery instead of
	# retracting it inside fences, which slices huge shapes across the screen.
	var shoulder := camera_focus+orbit*Vector3(CAMERA_LEFT_OFFSET,0,0)
	camera.global_position = shoulder+orbit*Vector3(0,0,camera_arm_distance)
	camera.global_basis = orbit

func apply_illustrated_materials(model: Node3D) -> void:
	var outline := ShaderMaterial.new()
	outline.shader = load("res://shaders/character_outline.gdshader")
	for instance in model.find_children("*", "MeshInstance3D", true, false):
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
	var preview_path := "C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/" + filename
	get_viewport().get_texture().get_image().save_png(preview_path)
	get_tree().quit()




func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle_overview()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		flip_camera()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		show_full_roof = not show_full_roof


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
	camera_finish = material
	material.set_shader_parameter("playable_min",Vector2(-27.35*map_scale.x,-19.35*map_scale.z))
	material.set_shader_parameter("playable_max",Vector2(27.35*map_scale.x,28.35*map_scale.z))
	material.render_priority = 127
	frame.material_override = material
	camera.add_child(frame)







func style_purple_tricycle(court: Node3D) -> void:
	for tricycle in court.get_node("StreetDetails").get_children():
		if not String(tricycle.name).begins_with("PurpleStreetTricycle"): continue
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
	if is_instance_valid(camera_finish):
		var player_view := camera.global_transform.affine_inverse()*(player.get_global_transform_interpolated().origin+Vector3(0,1.0,0))
		camera_finish.set_shader_parameter("focus_depth",maxf(0.1,-player_view.z))
		camera_finish.set_shader_parameter("distance_focus_enabled",0.0 if overview else 1.0)
	var screen_size := get_viewport().get_visible_rect().size
	var screen_position := camera.unproject_position(player.position + Vector3(0,0.8,0))
	var focus := screen_position / screen_size
	if is_instance_valid(camera_finish): camera_finish.set_shader_parameter("player_focus_uv",focus)
	if overview:
		focus = Vector2(0.5,0.5)
	for material in roof_paints:
		material.set_shader_parameter("cutaway",not show_full_roof)
		material.set_shader_parameter("focus_uv",focus)
		material.set_shader_parameter("cutaway_radius",0.65 if overview else 0.92)


















