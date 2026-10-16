extends SceneTree

var scenery := Node3D.new()
var batches: Dictionary = {}
var materials: Dictionary = {}
var region := "North"
var rng := RandomNumberGenerator.new()

func _initialize(): call_deferred("build")

func paint(key: String, color: String) -> Material:
	if not materials.has(key):
		var material := ShaderMaterial.new()
		material.resource_name = "Neighborhood_"+key
		material.shader = load("res://shaders/neighborhood_finish.gdshader")
		material.set_shader_parameter("base_color",Color(color))
		material.set_shader_parameter("planted_ground",1.0 if key=="Soil" else 0.0)
		material.set_shader_parameter("grain_texture",load("res://assets/environment/concrete.png"))
		materials[key] = material
	return materials[key]

func add_mesh(mesh: Mesh, transform: Transform3D, key: String, color: String) -> void:
	var batch_key := region+"_"+key
	if not batches.has(batch_key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(paint(key,color))
		batches[batch_key] = surface
	batches[batch_key].append_from(mesh,0,transform)

func box(pos: Vector3, size: Vector3, key: String, color: String, yaw: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	add_mesh(mesh,Transform3D(Basis(Vector3.UP,yaw),pos),key,color)

func cylinder(pos: Vector3, radius: float, height: float, key: String, color: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius*0.8
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	add_mesh(mesh,Transform3D(Basis.IDENTITY,pos),key,color)

func crown(pos: Vector3, size: Vector3, key: String, color: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 4
	mesh.radius = 1
	mesh.height = 2
	add_mesh(mesh,Transform3D(Basis.IDENTITY.scaled(size),pos),key,color)

# Reuse one mesh and texture per asset. Region batches retain frustum culling.
var imported_batches: Dictionary = {}

func model(key: String, pos: Vector3, height: float, yaw: float = 0.0):
	var batch_key := region+"_"+key
	if not imported_batches.has(batch_key): imported_batches[batch_key] = {"asset":key,"transforms":[]}
	# Cancel the map's nonuniform scale on the model itself, preserving its proportions.
	var basis := Basis(Vector3.UP,yaw).scaled(Vector3(height/.864618, height, height/.765034))
	imported_batches[batch_key].transforms.append(Transform3D(basis,pos))

func tree(pos: Vector3, height: float) -> void:
	model("shade_tree",pos,height,rng.randf_range(-PI,PI))

func palm(pos: Vector3) -> void:
	model("banana_plant",pos,3.8,rng.randf_range(-PI,PI))

func planter(pos: Vector3) -> void:
	model("croton_plant",pos,1.05,rng.randf_range(-PI,PI))

func bench(pos: Vector3, yaw: float = 0.0) -> void:
	model("park_bench",pos,1.05,yaw)

func stall(pos: Vector3, _tint: String, _title: String) -> void:
	model("palamig_cart",pos,2.35,PI)

func ground_strip(pos: Vector3, size: Vector3) -> void:
	box(pos,size,"Soil","b4a283")

func build():
	rng.seed = 67123
	scenery.name = "NeighborhoodBackdrop"
	region = "North"
	ground_strip(Vector3(0,0.065,-30),Vector3(100,0.07,20))
	box(Vector3(0,0.12,-21.5),Vector3(64,0.10,2),"Stone","bdb4a0")
	box(Vector3(0,0.68,-25.5),Vector3(66,1.2,0.3),"Plaster","baaa8b")
	box(Vector3(0,1.33,-25.5),Vector3(66,0.1,0.45),"Cream","e0d4b6")
	for x in [-17,17]: palm(Vector3(x,0.1,-32))
	for x in [-29,-19,-9,2,13,24,34]: tree(Vector3(x,0.1,-29),rng.randf_range(4.2,5.8))
	for x in [-22,-8,8,22]: bench(Vector3(x,0.2,-22.0))
	region = "South"
	ground_strip(Vector3(0,0.065,38),Vector3(100,0.07,17))
	box(Vector3(0,0.15,31.2),Vector3(70,0.16,2.8),"Stone","bdb4a0")
	box(Vector3(0,0.6,37),Vector3(68,1.1,0.25),"Plaster","baaa8b")
	box(Vector3(0,1.2,37),Vector3(68,0.1,0.42),"Cream","e0d4b6")
	for x in [-24,23]: palm(Vector3(x,0.1,39))
	for x in [-29,-18,-4,12,27,38]: tree(Vector3(x,0.1,40),rng.randf_range(4.0,5.4))
	stall(Vector3(-12,0.23,33.2),"Sage","PALAMIG")
	stall(Vector3(11,0.23,33.2),"Ochre","MERIENDA")
	for x in [-23,0,23]: bench(Vector3(x,0.23,31.7),PI)
	for x in [-26,-16,-8,7,15,27]: planter(Vector3(x,0.23,31.8))
	for side in [-1,1]:
		region = "West" if side<0 else "East"
		ground_strip(Vector3(side*40,0.065,3),Vector3(20,0.07,56))
		box(Vector3(side*31.3,0.12,3),Vector3(2,0.1,46),"Stone","bdb4a0")
		box(Vector3(side*35,0.65,3),Vector3(0.3,1.2,46),"Plaster","baaa8b")
		box(Vector3(side*35,1.3,3),Vector3(0.45,0.1,46),"Cream","e0d4b6")
		palm(Vector3(side*38,0.1,1))
		for z in [-18,-5,8,21]:
			tree(Vector3(side*40,0.1,z),rng.randf_range(4.0,5.8))
			planter(Vector3(side*32,0.2,z+3))
		for z in [-9,15]: bench(Vector3(side*31.5,0.2,z),side*PI/2)
	# Tiny chips/grass at outer corners, all beyond the collision boundary.
	for key in batches:
		var instance := MeshInstance3D.new()
		instance.name = key
		instance.mesh = batches[key].commit()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 95.0
		scenery.add_child(instance)
		instance.owner = scenery
	var total_instances := 0
	for batch_key in imported_batches:
		var data: Dictionary = imported_batches[batch_key]
		var prepared = load("res://assets/props/neighborhood/"+data.asset+".tscn").instantiate()
		var shared_mesh: Mesh = prepared.get_node("Model").mesh
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = shared_mesh
		multimesh.instance_count = data.transforms.size()
		for i in range(data.transforms.size()): multimesh.set_instance_transform(i,data.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Meshy_"+batch_key
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 95.0
		scenery.add_child(instance)
		instance.owner = scenery
		total_instances += multimesh.instance_count
		prepared.free()
	# Allow MultiMesh buffers to reach the renderer before serializing them.
	for i in range(3): await RenderingServer.frame_post_draw
	scenery.set_meta("meshy_instances",total_instances)
	scenery.set_meta("background_batch_count",batches.size()+imported_batches.size())
	scenery.set_meta("visual_only",true)
	var packed := PackedScene.new()
	assert(packed.pack(scenery)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/neighborhood_backdrop.tscn")==OK)
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	for child in court.get_children():
		if String(child.name) in ["Meshy_Autumn Croton_1","Meshy_Weathered Park Bench","Meshy_Twisted Canopy","Meshy_Rainbow Refreshment Cart","Meshy_Banana Tree"]:
			child.free()
	var previous = court.get_node_or_null("NeighborhoodBackdrop")
	if previous: previous.free()
	var instance = load("res://scenes/neighborhood_backdrop.tscn").instantiate()
	court.add_child(instance)
	instance.owner = court
	var saved := PackedScene.new()
	assert(saved.pack(court)==OK)
	assert(ResourceSaver.save(saved,"res://scenes/barangay_court.tscn")==OK)
	print("NEW MESHY BACKDROP SAVED: ",total_instances," instances in ",imported_batches.size()," shared model batches; old proxy trees/plants/benches/carts replaced; ground and walls retained.")
	court.free()
	scenery.free()
	quit()



