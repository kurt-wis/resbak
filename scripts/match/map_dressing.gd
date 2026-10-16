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

## Full-screen ink edges on the camera (the court's illustrated look). Outside `play` (XZ) the
## shader softly blurs and hazes the neighbourhood so the playable court reads first.
static func add_ink_edges(camera: Camera3D, play := Rect2()) -> ShaderMaterial:
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
	if play.size != Vector2.ZERO:
		material.set_shader_parameter("playable_min", play.position - Vector2(0.3, 0.3))
		material.set_shader_parameter("playable_max", play.end + Vector2(0.3, 0.3))
	material.render_priority = 127
	frame.material_override = material
	camera.add_child(frame)
	return material
