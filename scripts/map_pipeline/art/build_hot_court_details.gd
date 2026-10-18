extends SceneTree

var details := Node3D.new()
var batches: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _initialize(): call_deferred("build")

func material(hex: String) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = load("res://shaders/neighborhood_finish.gdshader")
	paint.set_shader_parameter("base_color",Color(hex))
	paint.set_shader_parameter("grain_texture",load("res://assets/environment/concrete.png"))
	return paint

func add_mesh(mesh: Mesh, transform: Transform3D, hex: String):
	if not batches.has(hex):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(material(hex))
		batches[hex] = st
	batches[hex].append_from(mesh,0,transform)

func text_node(text: String, pos: Vector3, size: float):
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.pixel_size = size
	mesh.font_size = 64
	mesh.depth = .005
	var instance := MeshInstance3D.new()
	instance.name = "CourtIdentity"
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material("efe0b9")
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	details.add_child(instance)
	instance.owner = details

func build():
	rng.seed = 67123
	details.name = "HotCourtDetails"
	# Small, intentional clusters stay near curbs, drains and stored props.
	var clusters = [Vector3(-23,1.54,-4),Vector3(23,1.54,8),Vector3(-23,1.54,10.7),Vector3(-23,.24,17.4),Vector3(23,.24,17.5),Vector3(-9,.24,17.6),Vector3(9,.24,17.6),Vector3(-28,.1,-10),Vector3(28,.1,10)]
	for cluster in clusters:
		for i in range(5):
			var pos: Vector3 = cluster+Vector3(rng.randf_range(-.8,.8),0,rng.randf_range(-.45,.45))
			var basis := Basis(Vector3.UP,rng.randf_range(-PI,PI))
			if i%3==0:
				var paper := BoxMesh.new()
				paper.size = Vector3(.18,.025,.26)
				add_mesh(paper,Transform3D(basis,pos),"e0d2ac")
				var print_strip := BoxMesh.new()
				print_strip.size = Vector3(.14,.008,.065)
				add_mesh(print_strip,Transform3D(basis,pos+Vector3.UP*.018),"658f88" if i==0 else "c28455")
			elif i%3==1:
				var leaf := SphereMesh.new()
				leaf.radial_segments = 6
				leaf.rings = 2
				add_mesh(leaf,Transform3D(basis.scaled(Vector3(.09,.016,.19)),pos),"b49b5d")
			else:
				var can := CylinderMesh.new()
				can.radial_segments = 8
				can.rings = 1
				can.top_radius = .055
				can.bottom_radius = .055
				can.height = .17
				add_mesh(can,Transform3D(basis*Basis(Vector3.RIGHT,PI/2),pos+Vector3.UP*.05),"8faaa3")
	# One restrained identity sign, mounted above the rear stand, not in the sightline.
	var board := BoxMesh.new()
	board.size = Vector3(7.8,1.65,.09)
	add_mesh(board,Transform3D(Basis.IDENTITY,Vector3(-14,6.1,-16.7)),"527b76")
	text_node("RESBAK",Vector3(-14,6.30,-16.635),.019)
	text_node("LARO SA KANTO",Vector3(-14,5.78,-16.635),.006)
	for hex in batches:
		var instance := MeshInstance3D.new()
		instance.name = "EdgeDetails_"+hex
		instance.mesh = batches[hex].commit()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		details.add_child(instance)
		instance.owner = details
	details.set_meta("litter_piece_count",45)
	var packed := PackedScene.new()
	assert(packed.pack(details)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/hot_court_details.tscn")==OK)
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	var old = court.get_node_or_null("HotCourtDetails")
	if old: old.free()
	var saved_details = load("res://scenes/hot_court_details.tscn").instantiate()
	court.add_child(saved_details)
	saved_details.owner = court
	var floor_mesh = court.get_node("CourtFloor/OrangeBasketballCourt")
	var paint: ShaderMaterial = floor_mesh.get_active_material(0).duplicate()
	paint.set_shader_parameter("base_color",Color("c17f57"))
	paint.set_shader_parameter("court_finish",1.0)
	paint.set_shader_parameter("court_scale",Vector2(court.scale.x,court.scale.z))
	floor_mesh.material_override = paint
	var saved := PackedScene.new()
	assert(saved.pack(court)==OK)
	assert(ResourceSaver.save(saved,"res://scenes/barangay_court.tscn")==OK)
	print("HOT COURT DETAILS SAVED: 45 small litter pieces in edge clusters, ",batches.size()," geometry batches, RESBAK sign, teal court keys and center pigment; no added collision.")
	court.free()
	details.free()
	quit()
