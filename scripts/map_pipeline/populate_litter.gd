# DESTRUCTIVE one-shot builder: overwrites scenes/barangay_court.tscn on disk.
# Already applied; do not run to inspect. See scripts/map_pipeline/README.md.
extends SceneTree
func _initialize() -> void:
	call_deferred("populate")
func populate() -> void:
	var court = load("res://scenes/barangay_court.tscn").instantiate()
	root.add_child(court)
	court.scene_file_path = ""
	var seeds := [11,31,47,81,19,99]
	var index := 0
	for batch in court.get_node("StreetLitter").get_children():
		var random := RandomNumberGenerator.new()
		random.seed = seeds[index]
		var multi: MultiMesh = batch.multimesh
		for i in range(multi.instance_count):
			var point := Vector3.ZERO
			if i%4 < 2:
				point = Vector3((-1 if i%2==0 else 1)*random.randf_range(17.85,19.0),.065,random.randf_range(-10.6,10.4))
			elif i%4==2:
				var x := random.randf_range(-18.2,18.2)
				if absf(absf(x)-7.0) < 2.0: x += 3.0 if x>0 else -3.0
				point = Vector3(x,.185,random.randf_range(11.45,12.35))
			else:
				point = Vector3((-1 if i%2==0 else 1)*random.randf_range(5.0,8.3),.065,random.randf_range(-10.8,-8.0))
			var factor := random.randf_range(.9,1.5)
			var rotation := Vector3(0,random.randf_range(-PI,PI),0)
			if batch.name == "DiscardedBottles":
				rotation.x = PI/2
				point.y += .025
			var basis := Basis.from_euler(rotation).scaled(Vector3.ONE*factor)
			multi.set_instance_transform(i,Transform3D(basis,point))
			var shade := random.randf_range(.83,1.0)
			multi.set_instance_color(i,Color(shade,shade,shade,1))
		index += 1
	for frame in range(3):
		await RenderingServer.frame_post_draw
	var total := 0
	for batch in court.get_node("StreetLitter").get_children():
		assert(batch.multimesh.buffer.size() > 0,"Litter transforms must serialize")
		total += batch.multimesh.instance_count
	var packed := PackedScene.new()
	packed.pack(court)
	ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")
	print("LITTER VERIFIED: ",total," visible instances with saved transforms")
	court.free()
	quit()
