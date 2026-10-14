extends SceneTree
func _initialize(): call_deferred("apply")
func material(hex: String)->ShaderMaterial:
 var m:=ShaderMaterial.new()
 m.shader=load("res://shaders/painted_architecture.gdshader")
 m.set_shader_parameter("painted_surface",load("res://assets/environment/painted_concrete_tile.png"))
 m.set_shader_parameter("tint",Color(hex))
 return m
func apply():
 var court=load("res://scenes/barangay_court.tscn").instantiate()
 root.add_child(court); court.scene_file_path=""
 var wall=material("96949a")
 var white=material("b5b0a3")
 var blue=material("526b80")
 for node in court.get_node("Architecture").get_children():
  if "Pillar" in String(node.name):
   node.get_node("CreamShaft").material_override=white
   node.get_node("TopCap").material_override=white
   node.get_node("BluePedestal").material_override=blue
   if node.has_node("WeatheredBlueLowerPaint"): node.get_node("WeatheredBlueLowerPaint").material_override=blue
  elif "Wall" in String(node.name) and node.has_node("PaintedSurface"):
   node.get_node("PaintedSurface").material_override=wall
 for frame in range(3): await RenderingServer.frame_post_draw
 var packed=PackedScene.new(); assert(packed.pack(court)==OK)
 assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 print("Applied world-scaled painted concrete to walls and two-color pillars")
 court.free()
 await process_frame
 quit()
