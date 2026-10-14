extends SceneTree
func _initialize() -> void:
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	root.add_child(court)
	court.scene_file_path = ""
	for x in [-7,7]:
		for prefix in ["CourtEntranceRamp","StreetAccessRamp"]:
			var body = court.get_node("StreetDetails/"+prefix+str(x))
			var arrays = body.get_node("ConcreteRamp").mesh.surface_get_arrays(0)
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			body.get_node("ConcreteRamp").mesh = mesh
			var shape := mesh.create_trimesh_shape()
			shape.backface_collision = true
			body.get_node("RampCollision").shape = shape
	var packed := PackedScene.new()
	packed.pack(court)
	ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")
	court.free()
	quit()
