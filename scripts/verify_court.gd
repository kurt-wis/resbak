extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene = load("res://scenes/court_playtest.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	var court = scene.get_node("BarangayCourt")
	assert(court.get_node("BaseSites").find_children("*_Site_*", "Area3D", false, false).size() == 6)
	assert(court.get_node("JailZones").find_children("*Jail", "Area3D", false, false).size() == 2)
	assert(scene.camera.size < 10.0, "Gameplay camera must start close")
	assert(court.get_node("CourtFloor/PaintedCourt").mesh != null, "Painted floor must keep its mesh")
	assert(court.get_node("CourtRoof/WestRoofSlope").mesh != null)
	assert(court.get_node("CourtRoof/EastRoofSlope").mesh != null)
	scene.show_full_roof = true
	scene.update_roof_cutaway()
	for material in scene.roof_paints:
		assert(material.get_shader_parameter("cutaway") == false)
	scene.show_full_roof = false
	scene.update_roof_cutaway()
	for material in scene.roof_paints:
		assert(material.get_shader_parameter("cutaway") == true)
	for shape in court.find_children("*", "CollisionShape3D", true, false):
		assert(shape.shape != null, "Every collision node must retain its shape")
	var body: CharacterBody3D = scene.player
	body.position = Vector3(-10,0.2,0)
	for tick in range(260):
		await physics_frame
		body.velocity = Vector3(5,-5,0)
		body.move_and_slide()
	assert(body.position.x > 10.0, "Center route must remain traversable")
	body.position = Vector3(18.5,0.2,0)
	for tick in range(80):
		await physics_frame
		body.velocity = Vector3(5,-5,0)
		body.move_and_slide()
	assert(body.position.x < 19.6, "Perimeter must stop character")
	assert(body.position.y > -0.1, "Floor collision must support character")
	print("COURT CHECKS PASSED: close camera, roof toggles, intact mesh/collision links, six sites, two jail zones, center traversal, perimeter and floor collision")
	quit()

