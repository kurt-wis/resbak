extends SceneTree
func _initialize():call_deferred("apply")
func state(court: Node3D)->Dictionary:
 var result={}
 for node in court.find_children("*","Node3D",true,false):
  if not String(node.name).begins_with("FlatDampRoadPatch"):result[str(court.get_path_to(node))]=node.transform
 return result
func apply():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court)
 var before=state(court);var removed=0;var updated={}
 for node in court.find_children("FlatDampRoadPatch*","MeshInstance3D",true,false):node.free();removed+=1
 var fine=load("res://assets/environment/concrete.png")
 var palette={Color("a4835a"):Color("b57957"),Color("b8b4a0"):Color("b9b7aa"),Color("b58755"):Color("b58d60"),Color("a39f8f"):Color("a3a092"),Color("8d8778"):Color("969182")}
 for visual in court.find_children("*","MeshInstance3D",true,false):
  var mat=visual.material_override
  if not mat is ShaderMaterial:continue
  var shader=mat.shader.resource_path
  if shader not in ["res://shaders/reference_paint.gdshader","res://shaders/reference_closed_concrete.gdshader","res://shaders/reference_asphalt.gdshader"]:continue
  if updated.has(mat.get_instance_id()):continue
  mat.set_shader_parameter("fine_texture",fine)
  if shader!="res://shaders/reference_asphalt.gdshader":
   var original:Color=mat.get_shader_parameter("base_color")
   for source in palette:
    if original.is_equal_approx(source):mat.set_shader_parameter("base_color",palette[source]);break
  updated[mat.get_instance_id()]=true
 assert(state(court)==before,"Object placements must remain unchanged")
 assert(court.get_node("FrontWallDecals").get_child_count()==8)
 var packed=PackedScene.new();assert(packed.pack(court)==OK);assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 print("SAVED: removed ",removed," damp patches; updated ",updated.size()," shared finishes; preserved all other transforms, 8 decals and existing collision")
 court.free();await process_frame;quit()
