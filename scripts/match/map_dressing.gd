class_name MapDressing
extends RefCounted

## Lighting, environment and small art passes for a match map (moved from court_playtest.gd
## so the match and the dev playtest look the same). Presentation only.

static func add_lighting(parent: Node3D, shadows := true) -> void:
	RenderingServer.set_default_clear_color(Color("d0c6b7"))
	var light := DirectionalLight3D.new()
	light.name = "WarmAfternoonSun"
	light.rotation_degrees = Vector3(-38, -38, 0)
	light.light_color = Color("ffe1b8")
	light.light_energy = 0.80
	light.shadow_enabled = shadows
	light.shadow_opacity = 0.68
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 65.0
	light.directional_shadow_blend_splits = true
	light.shadow_bias = 1.0
	light.shadow_normal_bias = 3.0
	parent.add_child(light)
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("9faad9")
	world.environment.ambient_light_energy = 0.16
	world.environment.adjustment_enabled = true
	world.environment.adjustment_contrast = 1.06
	world.environment.adjustment_saturation = 0.95
	parent.add_child(world)

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

## Full-screen ink edges on the camera (the court's illustrated look).
static func add_ink_edges(camera: Camera3D) -> void:
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
	material.render_priority = 127
	frame.material_override = material
	camera.add_child(frame)
