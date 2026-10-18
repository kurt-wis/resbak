extends Node3D

var player: CharacterBody3D
var visual: Node3D
var model: Node3D
var camera: Camera3D
var animator: AnimationPlayer
var touch_direction := Vector2.ZERO
var speed := 5.0

# animation clips (locomotion only - dash/roll/slide removed)
var idle_clip := ""
var walk_clip := ""
var run_clip := ""
var base_cam_size := 10.0

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
	RenderingServer.set_default_clear_color(Color("aec9d1"))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	block(Vector3(0,-0.25,0),Vector3(24,0.5,20),Color("b7b093"))
	for pos in [Vector3(-12,1,0),Vector3(12,1,0)]:
		block(pos,Vector3(0.5,2,20),Color("516b71"))
	for pos in [Vector3(0,1,-10),Vector3(0,1,10)]:
		block(pos,Vector3(24,2,0.5),Color("516b71"))
	for pos in [Vector3(-4,0.5,-2),Vector3(4,0.5,2)]:
		block(pos,Vector3(3,1,2),Color("bb7952"))
	block(Vector3(-8,0.025,0),Vector3(3,0.05,3),Color("388ee0"))
	block(Vector3(8,0.025,0),Vector3(3,0.05,3),Color("dc665c"))
	player = CharacterBody3D.new()
	player.position = Vector3(0,0.2,3)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	collision.shape = capsule
	collision.position.y = 0.8
	player.add_child(collision)
	visual = Node3D.new()
	player.add_child(visual)
	add_child(player)
	model = load("res://assets/characters/batang_hamog.glb").instantiate() as Node3D
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
	animator = null
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animator = node as AnimationPlayer
		break
	setup_animator()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = base_cam_size
	camera.current = true
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "RESBAK | BATANG HAMOG TEST\nWASD / arrows or touch to move | Shift sprint"
	label.position = Vector2(20,15)
	label.add_theme_color_override("font_color",Color("152c36"))
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
	if "--capture-preview" in OS.get_cmdline_user_args():
		capture_preview.call_deferred()

func setup_animator() -> void:
	if animator == null:
		return
	for clip in animator.get_animation_list():
		var low := clip.to_lower()
		var anim: Animation = animator.get_animation(clip)
		if "idle" in low:
			idle_clip = clip
			anim.loop_mode = Animation.LOOP_LINEAR
		elif "walk" in low:
			walk_clip = clip
			anim.loop_mode = Animation.LOOP_LINEAR
		elif "run" in low:
			if run_clip == "" or low == "running":
				run_clip = clip
			anim.loop_mode = Animation.LOOP_LINEAR
		# Dash / roll / slide / Harurot clips are intentionally ignored (removed).
	if walk_clip == "" and run_clip != "":
		walk_clip = run_clip
	if idle_clip != "":
		animator.play(idle_clip)
	elif walk_clip != "":
		animator.play(walk_clip)

func _play_clip(name: String, spd: float = 1.0) -> void:
	if animator == null or name == "" or not animator.has_animation(name):
		return
	if animator.current_animation != name:
		animator.play(name, 0.15, spd)
	else:
		animator.speed_scale = spd

func _physics_process(delta: float) -> void:
	var input := touch_direction
	input.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	input.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	input = input.limit_length()
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT)
	var move_speed := speed * (1.75 if sprinting else 1.0)
	player.velocity.x = input.x * move_speed
	player.velocity.z = input.y * move_speed
	if input.length() > 0.1:
		if sprinting:
			_play_clip(run_clip, 1.2)
		else:
			_play_clip(walk_clip, 1.05)
	else:
		_play_clip(idle_clip, 1.0)
	if not player.is_on_floor():
		player.velocity.y -= 20 * delta
	else:
		player.velocity.y = 0
	player.move_and_slide()
	if input.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(input.x,input.y),min(15*delta,1.0))
	if model:
		model.rotation.x = lerpf(model.rotation.x, 0.0, min(10.0*delta,1.0))
	visual.position.y = lerpf(visual.position.y, 0.0, min(10.0*delta,1.0))
	camera.size = base_cam_size
	camera.position = player.position + Vector3(0,14,10)
	camera.look_at(player.position + Vector3(0,0.5,0))

func apply_illustrated_materials(m: Node3D) -> void:
	var outline := ShaderMaterial.new()
	outline.shader = load("res://shaders/character_outline.gdshader")
	outline.set_shader_parameter("outline_pixels", (load(Tuning.PATH) as Tuning).character_outline_pixels)
	for instance in m.find_children("*", "MeshInstance3D", true, false):
		for surface in range(instance.mesh.get_surface_count()):
			var source = instance.get_active_material(surface)
			if source is StandardMaterial3D:
				var toon := ShaderMaterial.new()
				toon.shader = load("res://shaders/character_toon.gdshader")
				toon.set_shader_parameter("base_texture", source.albedo_texture)
				toon.set_shader_parameter("base_color", source.albedo_color)
				toon.next_pass = outline
				instance.set_surface_override_material(surface, toon)

func capture_preview() -> void:
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://outline-preview.png")
	get_tree().quit()
