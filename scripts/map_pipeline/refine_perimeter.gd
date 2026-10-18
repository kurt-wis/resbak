# DESTRUCTIVE one-shot builder: overwrites scenes/barangay_court.tscn on disk.
# Already applied; do not run to inspect. See scripts/map_pipeline/README.md.
extends SceneTree
var court: Node3D

func _initialize() -> void:
	call_deferred("refine")

func paint(color: Color, name: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = name
	material.shader = load("res://shaders/painted_architecture.gdshader")
	material.set_shader_parameter("painted_surface",load("res://assets/environment/painted_concrete_tile.res"))
	material.set_shader_parameter("tint",color)
	return material

func standard(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic_specular = 0.0
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func litter_batch(name: String, mesh: Mesh, material: Material, count: int, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var batch := MultiMeshInstance3D.new()
	batch.name = name
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	for i in range(count):
		var point := Vector3.ZERO
		if i % 4 < 2:
			point = Vector3((-1 if i%2==0 else 1)*random.randf_range(17.85,19.0),.05,random.randf_range(-10.6,10.4))
		elif i%4==2:
			var x := random.randf_range(-18.2,18.2)
			if absf(absf(x)-7.0) < 2.0: x += 3.0 if x>0 else -3.0
			point = Vector3(x,.185,random.randf_range(11.45,12.35))
		else:
			point = Vector3((-1 if i%2==0 else 1)*random.randf_range(5.0,8.3),.05,random.randf_range(-10.8,-8.0))
		var scale_factor := random.randf_range(.7,1.3)
		var basis := Basis.from_euler(Vector3(0,random.randf_range(-PI,PI),0)).scaled(Vector3.ONE*scale_factor)
		multi.set_instance_transform(i,Transform3D(basis,point))
		var shade := random.randf_range(.83,1.0)
		multi.set_instance_color(i,Color(shade,shade,shade,1))
	batch.multimesh = multi
	batch.material_override = material
	court.get_node("StreetLitter").add_child(batch)
	batch.owner = court

func refine() -> void:
	court = load("res://scenes/barangay_court.tscn").instantiate()
	root.add_child(court)
	court.scene_file_path = ""
	var wall_paint := paint(Color("b4b6bc"),"SharedWeatheredWallAndPillar")
	var blue_paint := paint(Color("6a7583"),"SlateBluePedestalPaint")
	var architecture := court.get_node("Architecture")
	for node in architecture.get_children():
		if "Pillar" in String(node.name):
			if String(node.name).begins_with("SidePillar"):
				node.position.x = signf(node.position.x)*19.92
			elif String(node.name).begins_with("RearPillar"):
				node.position.z = -12.05
			elif String(node.name).begins_with("EntrancePillar"):
				node.position.z = 11.28
			var shaft = node.get_node("CreamShaft")
			var geometry := BoxMesh.new()
			geometry.size = Vector3(.94,2.65,.94)
			shaft.mesh = geometry
			shaft.position.y = 1.965
			shaft.material_override = wall_paint
			node.get_node("TopCap").position.y = 3.38
			node.get_node("TopCap").material_override = wall_paint
			node.get_node("BluePedestal").material_override = blue_paint
			var collision = node.get_node("ShaftCollision")
			var shape := BoxShape3D.new()
			shape.size = Vector3(.94,2.65,.94)
			collision.shape = shape
			collision.position.y = 1.965
			# Narrow upper support reaches the canopy without projecting a huge concrete slab over the court.
			var support := MeshInstance3D.new()
			support.name = "UpperRoofSupport"
			support.position.y = 4.34
			var support_geometry := BoxMesh.new()
			support_geometry.size = Vector3(.28,1.7,.28)
			support.mesh = support_geometry
			support.material_override = blue_paint
			node.add_child(support)
			support.owner = court
		elif "Wall" in String(node.name) and node.has_node("PaintedSurface"):
			node.get_node("PaintedSurface").material_override = wall_paint
	var surface := ShaderMaterial.new()
	surface.resource_name = "SidewalkMatchesPaintedFloor"
	surface.shader = load("res://shaders/sidewalk_surface.gdshader")
	surface.set_shader_parameter("painted_ground",load("res://assets/environment/illustrated_court_ground.png"))
	var street := court.get_node("StreetDetails")
	for node in street.get_children():
		if String(node.name).begins_with("PerimeterStone"):
			node.free()
		elif node.name == "RaisedSidewalk":
			for child in node.get_children():
				if child is MeshInstance3D and String(child.name).begins_with("PavingSlab"):
					child.material_override = surface
		elif String(node.name).begins_with("CurbSection"):
			var visual = node.get_node("CurbFace")
			visual.material_override = surface
			var geometry := visual.mesh.duplicate() as BoxMesh
			geometry.size.y = .16
			geometry.size.z = .18
			visual.mesh = geometry
			visual.position.y = .08
			var collision = node.get_node("CurbCollision")
			var shape := collision.shape.duplicate() as BoxShape3D
			shape.size.y = .16
			shape.size.z = .18
			collision.shape = shape
			collision.position.y = .08
		elif "Ramp" in String(node.name):
			node.get_node("ConcreteRamp").material_override = surface
	var litter := Node3D.new()
	litter.name = "StreetLitter"
	court.add_child(litter)
	litter.owner = court
	# A few mesh batches keep the scattered detail inexpensive to draw.
	var paper := BoxMesh.new()
	paper.size = Vector3(.38,.012,.27)
	litter_batch("DiscardedPaper",paper,standard(Color("cfc4ae")),28,11)
	var cardboard := BoxMesh.new()
	cardboard.size = Vector3(.54,.025,.37)
	litter_batch("CardboardScraps",cardboard,standard(Color("9a8267")),17,31)
	var plank := BoxMesh.new()
	plank.size = Vector3(.65,.045,.13)
	litter_batch("BrokenWood",plank,standard(Color("94795d")),14,47)
	var bottle := CapsuleMesh.new()
	bottle.radius = .065
	bottle.height = .25
	bottle.radial_segments = 8
	bottle.rings = 2
	litter_batch("DiscardedBottles",bottle,standard(Color("68867c")),15,81)
	var tin := CylinderMesh.new()
	tin.top_radius = .07
	tin.bottom_radius = .07
	tin.height = .12
	tin.radial_segments = 8
	litter_batch("EmptyCans",tin,standard(Color("929da3")),12,19)
	var rubble := SphereMesh.new()
	rubble.radius = .15
	rubble.height = .10
	rubble.radial_segments = 8
	rubble.rings = 3
	litter_batch("ConcreteFragments",rubble,standard(Color("98928b")),24,99)
	var packed := PackedScene.new()
	assert(packed.pack(court)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
	print("REFINED: shared cool wall/pillar paint, outward pillars, shorter concrete shafts, continuous painted sidewalks, 110 litter pieces in six batches")
	court.free()
	quit()
