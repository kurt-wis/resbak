# LEGACY snapshot check: fails on the current map; not part of the gate.
# See scripts/tests/README.md.
extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var scene = load("res://scenes/court_playtest.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.set_physics_process(false)
	var court = scene.get_node("BarangayCourt")
	assert(not court.has_node("Architecture/BarangaySign"))
	assert(court.get_node("Architecture").find_children("*Pillar*","StaticBody3D",false,false).size()==15)
	var space = root.world_3d.direct_space_state
	var count := 0
	for group_name in ["CourtProps","StreetDetails"]:
		for prop in court.get_node(group_name).get_children():
			if not prop.has_node("SolidCollision/PropBounds"):
				continue
			var shape = prop.get_node("SolidCollision/PropBounds")
			var center: Vector3 = shape.global_position
			var ray := PhysicsRayQueryParameters3D.create(center+Vector3(0,4,0),center-Vector3(0,0.05,0))
			ray.exclude = [scene.player.get_rid()]
			var hit := space.intersect_ray(ray)
			assert(not hit.is_empty(), "Prop must block ray: "+str(prop.name))
			assert(hit.collider.name=="SolidCollision", "Prop collider must match its visible object: "+str(prop.name))
			count += 1
	assert(count==58)
	var body: CharacterBody3D = scene.player
	body.position = Vector3(7,.3,10)
	for tick in range(90):
		await physics_frame
		body.velocity = Vector3(0,-5,3)
		body.move_and_slide()
	print("RAMP POSITION: ",body.position)
	if body.get_slide_collision_count() > 0:
		print("BLOCKER: ",body.get_slide_collision(0).get_collider().get_path(), " NORMAL: ",body.get_slide_collision(0).get_normal())
	if body.position.z <= 13.4:
		quit(1)
		return
	for tick in range(90):
		await physics_frame
		body.velocity = Vector3(0,-5,-3)
		body.move_and_slide()
	assert(body.position.z < 10.8, "Character must be able to walk back into court")
	print("CLEANUP CHECKS PASSED: 58 prop collisions, 15 pillars, stage sign removed, sidewalk traversable both directions")
	quit()

