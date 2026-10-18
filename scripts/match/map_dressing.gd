class_name MapDressing
extends RefCounted

## Lighting, environment and small art passes for a match map (moved from court_playtest.gd
## so the match and the dev playtest look the same). Presentation only.

## Kurt's map-art daylight (court_playtest.gd): cooler sky, crisper sun, lifted ambient.
## A map that brings its own WorldEnvironment (the construction site) keeps its own lighting:
## pass it as `map` and only the shadow toggle is applied to its suns.
static func add_lighting(parent: Node3D, shadows := true, map: Node = null) -> void:
	if map and not map.find_children("*", "WorldEnvironment", true, false).is_empty():
		for sun in map.find_children("*", "DirectionalLight3D", true, false):
			if not shadows:
				(sun as DirectionalLight3D).shadow_enabled = false
		return
	RenderingServer.set_default_clear_color(Color("cad9d9"))
	var light := DirectionalLight3D.new()
	light.name = "WarmAfternoonSun"
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_color = Color("fff0d4")
	light.light_energy = 0.96
	light.shadow_enabled = shadows
	light.shadow_opacity = 0.76
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 65.0
	light.directional_shadow_blend_splits = true
	light.shadow_bias = 1.5
	light.shadow_normal_bias = 1.2
	parent.add_child(light)
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("9eb9d0")
	world.environment.ambient_light_energy = 0.29
	world.environment.adjustment_enabled = true
	world.environment.adjustment_contrast = 1.05
	world.environment.adjustment_saturation = 1.02
	parent.add_child(world)

## Looping map ambience (the court's daylight bed, -25 dB on the Music bus). Silent if missing.
static func add_ambience(parent: Node, path: String, volume_db := -25.0) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var stream := (load(path) as AudioStream)
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_end = int(stream.get_length() * (stream as AudioStreamWAV).mix_rate)
	var player := AudioStreamPlayer.new()
	player.name = "MapAmbience"
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	player.autoplay = true
	parent.add_child(player)
	return player

## Drifting dust (Konstruksyon's hot afternoon; a map opts in with `dust = true` on Gameplay).
## One CPUParticles3D (Compatibility-safe, no GPU particles) filling the play bounds, a slow
## cross-wind drift with soft warm specks. Skipped with Reduce motion.
static func add_dust(parent: Node, bounds: Rect2, profile: Dictionary = {}) -> CPUParticles3D:
	var save := parent.get_node_or_null("/root/Save")
	if save and bool(save.get_setting("accessibility", "reduce_motion")):
		return null
	var p := CPUParticles3D.new()
	p.name = "DriftingDust"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(profile.get("dust_size", 0.12))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = profile.get("dust_color", Color(0.93, 0.8, 0.58, 0.45))
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = int(profile.get("dust_amount", 140))
	p.lifetime = 9.0
	p.preprocess = 9.0 # already drifting when the map appears
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(bounds.size.x * 0.5, 1.6, bounds.size.y * 0.5)
	p.top_level = true # play bounds are world-space, including on scaled/offset court roots
	p.position = Vector3(bounds.get_center().x, 1.8, bounds.get_center().y)
	p.direction = Vector3(1, 0.05, 0.25)
	p.spread = 25.0
	p.initial_velocity_min = float(profile.get("dust_speed_min", 0.5))
	p.initial_velocity_max = float(profile.get("dust_speed_max", 1.3))
	p.gravity = Vector3(0, 0.02, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	parent.add_child(p)
	return p

## A map's own cameras (Mathew's InspectionCamera) must never take over the view.
static func disable_map_cameras(map: Node) -> void:
	for c in map.find_children("*", "Camera3D", true, false):
		(c as Camera3D).current = false
		c.queue_free()

static func dress_court(court: Node3D) -> void:
	var tricycle := court.get_node_or_null("StreetDetails/PurpleStreetTricycle")
	if tricycle:
		for mesh in tricycle.find_children("*", "MeshInstance3D", true, false):
			for surface in range((mesh as MeshInstance3D).mesh.get_surface_count()):
				var original := (mesh as MeshInstance3D).get_active_material(surface) as StandardMaterial3D
				if original:
					var paint := ShaderMaterial.new()
					paint.shader = load("res://shaders/purple_vehicle.gdshader")
					paint.set_shader_parameter("paint_texture", original.albedo_texture)
					(mesh as MeshInstance3D).set_surface_override_material(surface, paint)
	var shadow_paint := ShaderMaterial.new()
	shadow_paint.shader = load("res://shaders/painted_contact_shadow.gdshader")
	shadow_paint.render_priority = 90
	for group_name in ["CourtProps", "StreetDetails"]:
		var group := court.get_node_or_null(group_name)
		if group == null:
			continue
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
			plane.size = Vector2(maxf(bounds.size.x, 0.3) * 1.15, maxf(bounds.size.z, 0.3) * 1.1)
			shadow.mesh = plane
			shadow.position = Vector3(bounds.get_center().x, 0.036, bounds.get_center().z)
			shadow.material_override = shadow_paint
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(shadow)

	apply_court_summer(court)

## Opt-in instance overrides keep other maps and shared prop resources unchanged.
static func apply_court_summer(court: Node3D) -> void:
	var gameplay := court.get_node_or_null("Gameplay")
	var profile: Dictionary = gameplay.get_meta("presentation", {}) if gameplay else {}
	if not bool(profile.get("summer_finish", false)):
		return
	var save := court.get_node_or_null("/root/Save")
	var motion_off: bool = save != null and bool(save.get_setting("accessibility", "reduce_motion"))
	var cache := {}
	for node in court.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null)
		if mesh == null:
			continue
		if node.material_override:
			node.material_override = _summer_material(node.material_override, profile, motion_off, cache)
		elif node is MeshInstance3D:
			for index in range(mesh.get_surface_count()):
				var original: Material = node.get_active_material(index)
				if original:
					node.set_surface_override_material(index, _summer_material(original, profile, motion_off, cache))
		elif node is MultiMeshInstance3D:
			var copy: Mesh = mesh.duplicate()
			for index in range(mesh.get_surface_count()):
				var original: Material = mesh.surface_get_material(index)
				if original:
					copy.surface_set_material(index, _summer_material(original, profile, motion_off, cache))
			node.multimesh = node.multimesh.duplicate()
			node.multimesh.mesh = copy

static func _summer_material(original: Material, profile: Dictionary, motion_off: bool, cache: Dictionary) -> Material:
	if cache.has(original):
		return cache[original]
	var material := original.duplicate() as Material
	cache[original] = material
	if material is ShaderMaterial and material.shader:
		for uniform in material.shader.get_shader_uniform_list():
			if uniform.name == "summer_wear":
				material.set_shader_parameter("summer_wear", float(profile.get("summer_wear", 1.0)))
			elif uniform.name == "summer_breeze":
				material.set_shader_parameter("summer_breeze", 0.0 if motion_off else float(profile.get("summer_breeze", 1.0)))
	elif material is StandardMaterial3D:
		# Muted foliage/plastic accents; preserve texture, alpha and metallic identity.
		var color: Color = material.albedo_color
		var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
		material.albedo_color = Color(luminance, luminance, luminance, color.a).lerp(color, 0.94)
		material.roughness = maxf(material.roughness, 0.7)
	return material

## Full-screen ink edges on the camera (the court's illustrated look). Outside `play` (XZ) the
## shader softly blurs and hazes the neighbourhood so the playable court reads first.
static func add_ink_edges(camera: Camera3D, play := Rect2(), map: Node = null) -> ShaderMaterial:
	var frame := MeshInstance3D.new()
	frame.name = "IllustratedInkEdges"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	frame.mesh = quad
	frame.extra_cull_margin = 16384
	frame.position.z = -1
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/illustrated_edges.gdshader")
	material.set_shader_parameter("stroke_pixels", 0.8) # same finish as Konstruksyon's authored camera
	var gameplay := map.get_node_or_null("Gameplay") if map else null
	var profile: Dictionary = gameplay.get_meta("presentation", {}) if gameplay else {}
	for key in ["ink_color", "haze_color", "stroke_pixels"]:
		if profile.has(key):
			material.set_shader_parameter("ink" if key == "ink_color" else key, profile[key])
	if play.size != Vector2.ZERO:
		material.set_shader_parameter("playable_min", play.position - Vector2(0.3, 0.3))
		material.set_shader_parameter("playable_max", play.end + Vector2(0.3, 0.3))
	material.render_priority = 127
	frame.material_override = material
	camera.add_child(frame)
	return material
