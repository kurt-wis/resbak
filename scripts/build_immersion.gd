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

func tree(pos: Vector3, height: float) -> void:
	cylinder(pos+Vector3(0,height*0.4,0),0.18,height*0.8,"Timber","91734e")
	crown(pos+Vector3(0,height*0.8,0),Vector3(2.0,1.3,1.8),"Leaf","6e8859")
	crown(pos+Vector3(-1.0,height*0.71,0.1),Vector3(1.35,1.1,1.45),"Leaf","6e8859")
	crown(pos+Vector3(0.8,height*0.91,-0.2),Vector3(1.4,1.2,1.4),"YoungLeaf","8c9b66")
	for i in range(3):
		crown(pos+Vector3(-1.5+i*1.5,0.38,1.0),Vector3(0.8,0.45,0.7),"Shrub","7f8b59")

func palm(pos: Vector3) -> void:
	cylinder(pos+Vector3(0,2.3,0),0.16,4.6,"Timber","91734e")
	var leaf := SurfaceTool.new()
	leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(7):
		var angle := float(i)*TAU/7.0
		var along := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-sin(angle),0,cos(angle))
		var start := Vector3(0,4.6,0)
		var middle := start+along*1.3+Vector3.UP*0.3
		var tip := start+along*3.0-Vector3.UP*0.65
		var vertices = [start,middle+side*0.4,middle, middle,middle+side*0.4,tip, start,middle,middle-side*0.4, middle,tip,middle-side*0.4]
		for index in range(0,vertices.size(),3):
			leaf.add_vertex(vertices[index])
			leaf.add_vertex(vertices[index+2])
			leaf.add_vertex(vertices[index+1])
	leaf.generate_normals()
	var mesh := leaf.commit()
	add_mesh(mesh,Transform3D(Basis.IDENTITY,pos),"Palm","879b62")


func planter(pos: Vector3) -> void:
	cylinder(pos+Vector3(0,0.26,0),0.36,0.52,"Pot","b47a58")
	crown(pos+Vector3(0,0.75,0),Vector3(0.55,0.58,0.5),"YoungLeaf","8c9b66")

func bench(pos: Vector3, yaw: float = 0.0) -> void:
	for x in [-0.85,0.85]:
		box(pos+Basis(Vector3.UP,yaw)*Vector3(x,0.3,0),Vector3(0.2,0.6,0.65),"Stone","bdb4a0",yaw)
	for z in [-0.24,0.0,0.24]:
		box(pos+Basis(Vector3.UP,yaw)*Vector3(0,0.64,z),Vector3(2.4,0.12,0.2),"Timber","91734e",yaw)
	box(pos+Basis(Vector3.UP,yaw)*Vector3(0,1.0,0.36),Vector3(2.4,0.45,0.1),"Timber","91734e",yaw)

func stall(pos: Vector3, tint: String, title: String) -> void:
	box(pos+Vector3(0,0.72,0),Vector3(2.4,1.2,1.1),tint,"9aaba0" if tint=="Sage" else "c19466")
	box(pos+Vector3(0,1.37,0),Vector3(2.7,0.12,1.4),"Stone","bdb4a0")
	for x in [-1.15,1.15]:
		box(pos+Vector3(x,1.8,0.35),Vector3(0.065,1.2,0.065),"Timber","91734e")
	for i in range(8):
		box(pos+Vector3(-1.4+i*0.4,2.45,0),Vector3(0.4,0.10,1.9),"Cream" if i%2==0 else tint,"e0d4b6" if i%2==0 else ("9aaba0" if tint=="Sage" else "c19466"))
	for x in [-0.9,0.9]:
		cylinder(pos+Vector3(x,0.13,0),0.13,0.24,"Timber","91734e")
	for i in range(4):
		cylinder(pos+Vector3(-0.8+i*0.48,1.57,0),0.13,0.28,"Pot","b47a58")
	var sign_mesh := TextMesh.new()
	sign_mesh.text = title
	sign_mesh.font_size = 64
	sign_mesh.pixel_size = 0.006
	sign_mesh.depth = 0.008
	var sign := MeshInstance3D.new()
	sign.name = title+"Sign"
	sign.mesh = sign_mesh
	sign.position = pos+Vector3(0,1.0,-0.557)
	sign.rotation.y = PI
	sign.material_override = paint("Sign","e0d4b6")
	sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scenery.add_child(sign)
	sign.owner = scenery

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
	scenery.set_meta("background_batch_count",batches.size())
	scenery.set_meta("visual_only",true)
	var packed := PackedScene.new()
	assert(packed.pack(scenery)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/neighborhood_backdrop.tscn")==OK)
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	var previous = court.get_node_or_null("NeighborhoodBackdrop")
	if previous: previous.free()
	var instance = load("res://scenes/neighborhood_backdrop.tscn").instantiate()
	court.add_child(instance)
	instance.owner = court
	var saved := PackedScene.new()
	assert(saved.pack(court)==OK)
	assert(ResourceSaver.save(saved,"res://scenes/barangay_court.tscn")==OK)
	print("NEIGHBORHOOD SAVED: ",batches.size()," material/region batches; low-poly vegetation, benches, low walls and 2 market carts; no new physics bodies or lights.")
	court.free()
	scenery.free()
	quit()


