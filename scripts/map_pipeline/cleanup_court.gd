# DESTRUCTIVE one-shot builder: overwrites scenes/barangay_court.tscn on disk.
# Already applied; do not run to inspect. See scripts/map_pipeline/README.md.
extends SceneTree

var court: Node3D
var sidewalk_paint: ShaderMaterial
var pillar_paint: ShaderMaterial
var base_paint: ShaderMaterial
var ink: StandardMaterial3D

func _initialize() -> void:
	call_deferred("clean")

func own(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = court

func material(tint: Color, name: String) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.resource_name = name
	paint.shader = load("res://shaders/painted_architecture.gdshader")
	paint.set_shader_parameter("painted_surface",load("res://assets/environment/painted_concrete_tile.res"))
	paint.set_shader_parameter("tint",tint)
	return paint

func box_mesh(name: String, parent: Node3D, position: Vector3, size: Vector3, paint: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.resource_name = name + "Geometry"
	node.mesh = mesh
	node.material_override = paint
	own(node,parent)
	return node

func collision_box(name: String, parent: Node3D, position: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = name
	shape.position = position
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	own(shape,parent)

func pillar(name: String, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	own(body,court.get_node("Architecture"))
	box_mesh("BluePedestal",body,Vector3(0,.32,0),Vector3(1.20,.64,1.20),base_paint)
	box_mesh("CreamShaft",body,Vector3(0,2.81,0),Vector3(.94,4.34,.94),pillar_paint)
	box_mesh("TopCap",body,Vector3(0,5.07,0),Vector3(1.10,.18,1.10),pillar_paint)
	box_mesh("PaintBreak",body,Vector3(0,.655,0),Vector3(1.205,.035,1.205),ink)
	collision_box("PedestalCollision",body,Vector3(0,.32,0),Vector3(1.20,.64,1.20))
	collision_box("ShaftCollision",body,Vector3(0,2.81,0),Vector3(.94,4.34,.94))

func ramp(name: String, x: float, z_start: float, z_end: float, start_height: float, end_height: float) -> void:
	var width := 3.5
	var vertices := PackedVector3Array([
		Vector3(x-width/2,start_height,z_start),Vector3(x+width/2,start_height,z_start),
		Vector3(x+width/2,end_height,z_end),Vector3(x-width/2,end_height,z_end)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normal := Vector3(0,z_end-z_start,start_height-end_height).normalized()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal,normal,normal,normal])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,0,3,2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var body := StaticBody3D.new()
	body.name = name
	own(body,court.get_node("StreetDetails"))
	var visual := MeshInstance3D.new()
	visual.name = "ConcreteRamp"
	visual.mesh = mesh
	visual.material_override = sidewalk_paint
	own(visual,body)
	var shape := CollisionShape3D.new()
	shape.name = "RampCollision"
	shape.shape = mesh.create_trimesh_shape()
	own(shape,body)

func clean() -> void:
	court = load("res://scenes/barangay_court.tscn").instantiate()
	root.add_child(court)
	court.scene_file_path = ""
	sidewalk_paint = material(Color("aaa9a0"),"WeatheredSidewalkConcrete")
	pillar_paint = material(Color("d9d2bf"),"CreamPillarPlaster")
	base_paint = material(Color("61768e"),"BluePillarPedestal")
	ink = StandardMaterial3D.new()
	ink.resource_name = "ConcreteJointInk"
	ink.albedo_color = Color("4a4c56")
	ink.roughness = 1
	ink.metallic_specular = 0
	var architecture := court.get_node("Architecture")
	for node in architecture.get_children():
		if String(node.name).begins_with("Column") or String(node.name).begins_with("RearSupport") or node.name in ["BarangaySign","StageBackdrop"]:
			node.free()
	var street := court.get_node("StreetDetails")
	for node in street.get_children():
		if String(node.name).begins_with("ColumnPlinth") or String(node.name).begins_with("ColumnBand") or String(node.name).begins_with("SidewalkBlock") or String(node.name).begins_with("Drain"):
			node.free()
	# Build large readable, painted concrete columns instead of thin posts and floating caps.
	for side in [-1,1]:
		for z in [-11.6,-4.0,4.0,10.8]:
			pillar("SidePillar%s_%s" % [side,z],Vector3(side*19.35,0,z))
	for x in [-16,-8,0,8,16]:
		pillar("RearPillar"+str(x),Vector3(x,0,-11.6))
	for x in [-10,10]:
		pillar("EntrancePillar"+str(x),Vector3(x,0,11.0))
	# Clear the old metal extensions; the new concrete shafts connect directly to the roof.
	var roof := court.get_node("CourtRoof")
	for node in roof.get_children():
		if String(node.name).begins_with("ColumnExtension"):
			node.free()
	# Continuous raised sidewalk with real seams and two gentle entrance/road ramps.
	var walkway := StaticBody3D.new()
	walkway.name = "RaisedSidewalk"
	own(walkway,street)
	collision_box("ContinuousWalkwayCollision",walkway,Vector3(0,.08,12.0),Vector3(39.2,.16,1.25))
	for i in range(28):
		var x := -19.6 + (i+.5)*1.4
		box_mesh("PavingSlab%02d"%i,walkway,Vector3(x,.079,12.0),Vector3(1.385,.158,1.25),sidewalk_paint)
	# Curb sections leave openings for the two ramps to the street.
	for data in [[-14.05,11.1],[0.0,10.0],[14.05,11.1]]:
		var body := StaticBody3D.new()
		body.name = "CurbSection"+str(data[0])
		own(body,street)
		box_mesh("CurbFace",body,Vector3(data[0],.10,12.68),Vector3(data[1],.20,.12),sidewalk_paint)
		collision_box("CurbCollision",body,Vector3(data[0],.10,12.68),Vector3(data[1],.20,.12))
	for x in [-7,7]:
		ramp("CourtEntranceRamp"+str(x),x,10.95,11.52,.013,.16)
		ramp("StreetAccessRamp"+str(x),x,12.48,13.12,.16,.013)
	# Drain covers sit flush with paving instead of floating on the surface.
	for x in [-12,0,12]:
		box_mesh("DrainFrame"+str(x),walkway,Vector3(x,.163,12.0),Vector3(1.2,.014,.45),ink)
		for i in range(8):
			box_mesh("DrainGrate%s_%s"%[x,i],walkway,Vector3(x-.51+i*.145,.173,12.0),Vector3(.045,.012,.38),base_paint)
	# Every solid imported prop gets a collider nested under the prop itself.
	var total := 0
	for group_name in ["CourtProps","StreetDetails"]:
		var group := court.get_node(group_name)
		for node in group.get_children():
			if node is StaticBody3D and group_name == "CourtProps":
				node.free()
		for prop in group.get_children():
			if prop is not Node3D or prop is MeshInstance3D or prop is StaticBody3D:
				continue
			var meshes := prop.find_children("*", "MeshInstance3D", true, false)
			if meshes.is_empty():
				continue
			if prop.name == "RaisedSidewalk":
				continue
			var bounds := AABB()
			var first := true
			for mesh in meshes:
				var local: AABB = prop.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
				bounds = local if first else bounds.merge(local)
				first = false
			var body := StaticBody3D.new()
			body.name = "SolidCollision"
			own(body,prop)
			var size := bounds.size
			var center := bounds.get_center()
			if "Plant" in String(prop.name):
				size = Vector3(.46,.43,.46)
				center.y = bounds.position.y + .215
			collision_box("PropBounds",body,center,size)
			total += 1
	# Jail side rails are solid; their inner-facing rescue entrance stays open.
	for team in ["Yellow","Purple"]:
		var side := -1 if team == "Yellow" else 1
		var x := side*16.6
		var z := -side*7.2
		var body := StaticBody3D.new()
		body.name = team+"JailRailCollision"
		own(body,court.get_node("JailZones"))
		for dz in [-1.65,1.65]:
			collision_box("SideRail"+str(dz),body,Vector3(x,.55,z+dz),Vector3(4.1,1.1,.08))
		collision_box("OuterRail",body,Vector3(x+side*2,.55,z),Vector3(.08,1.1,3.3))
	var packed := PackedScene.new()
	assert(packed.pack(court)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
	print("CLEANUP COMPLETE: %d solid props, 15 reference-style pillars, raised sidewalk, four ramps, flush drains, stage text removed"%total)
	quit()
