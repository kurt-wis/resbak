extends SceneTree
func _initialize():call_deferred("check")
func check():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 var court=scene.get_node("BarangayCourt")
 var architecture=court.get_node("Architecture")
 var shared=architecture.get_node("SideWall1/PaintedSurface").material_override
 var count=0
 for node in architecture.get_children():
  if "Wall" in String(node.name):assert(node.get_node("PaintedSurface").material_override==shared)
  elif "Pillar" in String(node.name):
   count+=1
   for mesh in node.find_children("*","MeshInstance3D",true,false):assert(mesh.material_override==shared)
 assert(count==15)
 var wood=architecture.get_node("BarangayStage/PaintedSurface").material_override
 assert(wood.get_shader_parameter("wood_texture").resource_path=="res://assets/environment/illustrated_stage_wood.png")
 for name in ["StageStep0","StageStep1","StageStep2"]:assert(architecture.get_node(name+"/PaintedSurface").material_override==wood)
 scene.set_physics_process(false)
 scene.camera.size=6.0
 for data in [[Vector3(-10,.2,10),"resbak-wall-materials.png"],[Vector3(0,.2,-7),"resbak-stage-materials.png"]]:
  scene.player.position=data[0]
  var focus: Vector3=data[0]+Vector3(0,.65,0)
  scene.camera.position=focus+Vector3(0,11,7.5);scene.camera.look_at(focus)
  for frame in range(5):await process_frame
  await RenderingServer.frame_post_draw
  get_root().get_texture().get_image().save_png("C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/"+data[1])
 print("PERSISTED MATERIALS VERIFIED: identical wall/post material, consistent blue paint height; same generated wood on platform and all stairs")
 scene.free();await process_frame;quit()
