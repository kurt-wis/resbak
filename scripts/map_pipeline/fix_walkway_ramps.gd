# DESTRUCTIVE one-shot builder: overwrites scenes/barangay_court.tscn on disk.
# Already applied; do not run to inspect. See scripts/map_pipeline/README.md.
extends SceneTree
func _initialize() -> void:
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	root.add_child(court)
	court.scene_file_path = ""
	var walkway = court.get_node("StreetDetails/RaisedSidewalk")
	walkway.get_node("ContinuousWalkwayCollision").free()
	for data in [[-14.175,10.85],[0.0,10.5],[14.175,10.85]]:
		var shape := CollisionShape3D.new()
		shape.name = "WalkwaySegment"+str(data[0])
		shape.position = Vector3(data[0],.08,12)
		var box := BoxShape3D.new()
		box.size = Vector3(data[1],.16,1.25)
		shape.shape = box
		walkway.add_child(shape)
		shape.owner = court
	for x in [-7,7]:
		var shape := CollisionShape3D.new()
		shape.name = "AccessLanding"+str(x)
		shape.position = Vector3(x,.08,12)
		var box := BoxShape3D.new()
		box.size = Vector3(3.5,.16,.8)
		shape.shape = box
		walkway.add_child(shape)
		shape.owner = court
		for suffix in ["CourtEntranceRamp","StreetAccessRamp"]:
			var body = court.get_node("StreetDetails/"+suffix+str(x))
			var z_start := 10.95 if suffix=="CourtEntranceRamp" else 12.4
			var z_end := 11.6 if suffix=="CourtEntranceRamp" else 13.12
			var h_start := .013 if suffix=="CourtEntranceRamp" else .16
			var h_end := .16 if suffix=="CourtEntranceRamp" else .013
			var vertices := PackedVector3Array([Vector3(x-1.75,h_start,z_start),Vector3(x+1.75,h_start,z_start),Vector3(x+1.75,h_end,z_end),Vector3(x-1.75,h_end,z_end)])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var normal := Vector3(0,z_end-z_start,h_start-h_end).normalized()
			arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal,normal,normal,normal])
			arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,0,3,2])
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			body.get_node("ConcreteRamp").mesh = mesh
			body.get_node("RampCollision").shape = mesh.create_trimesh_shape()
	var packed := PackedScene.new()
	packed.pack(court)
	ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")
	court.free()
	quit()
