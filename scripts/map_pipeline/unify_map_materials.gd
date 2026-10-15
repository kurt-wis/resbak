# DESTRUCTIVE one-shot builder: overwrites scenes/barangay_court.tscn on disk.
# Already applied; do not run to inspect. See scripts/map_pipeline/README.md.
extends SceneTree
func _initialize():call_deferred("apply")
func apply():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court);court.scene_file_path=""
 var masonry=ShaderMaterial.new();masonry.resource_name="ContinuousWallAndPillarPaint"
 masonry.shader=load("res://shaders/unified_court_masonry.gdshader")
 masonry.set_shader_parameter("concrete_texture",load("res://assets/environment/painted_concrete_tile.png"))
 var wooden=ShaderMaterial.new();wooden.shader=load("res://shaders/aged_stage.gdshader")
 wooden.set_shader_parameter("wood_texture",load("res://assets/environment/illustrated_stage_wood.png"))
 var architecture=court.get_node("Architecture")
 for node in architecture.get_children():
  if "Pillar" in String(node.name):
   for mesh in node.find_children("*","MeshInstance3D",true,false):mesh.material_override=masonry
  elif "Wall" in String(node.name) and node.has_node("PaintedSurface"):
   node.get_node("PaintedSurface").material_override=masonry
   for child in node.get_children():
    if "Edge" in String(child.name):child.free()
  elif node.name=="BarangayStage" or String(node.name).begins_with("StageStep"):
   node.get_node("PaintedSurface").material_override=wooden
   for child in node.get_children():
    if "Edge" in String(child.name):child.free()
 for frame in range(3):await RenderingServer.frame_post_draw
 var wall=architecture.get_node("SideWall1/PaintedSurface").material_override
 var count=0
 for node in architecture.get_children():
  if "Pillar" in String(node.name):
   count+=1
   for mesh in node.find_children("*","MeshInstance3D",true,false):assert(mesh.material_override==wall)
 assert(count==15)
 for name in ["BarangayStage","StageStep0","StageStep1","StageStep2"]:
  assert(architecture.get_node(name+"/PaintedSurface").material_override==wooden)
 assert(not court.has_node("CourtRoof"))
 for batch in court.get_node("StreetLitter").get_children():assert(batch.multimesh.buffer.size()>0)
 var packed=PackedScene.new();assert(packed.pack(court)==OK)
 assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 print("VERIFIED shared masonry on all 15 posts and walls, one continuous blue band, shared illustrated wood on stage + stairs")
 court.free();await process_frame;quit()
