extends SceneTree
func _initialize():
 var art=load("res://assets/decals/front_wall_decals.tscn").instantiate()
 var warning=art.get_node("BawalWarningLeft");warning.position.y=1.4;warning.mesh=warning.mesh.duplicate();warning.mesh.size=Vector2(2.75,1.45)
 var packed=PackedScene.new();assert(packed.pack(art)==OK);assert(ResourceSaver.save(packed,"res://assets/decals/front_wall_decals.tscn")==OK)
 art.free();print("Raised left warning for clearance above existing stored props; no props moved");quit()
