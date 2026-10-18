# LEGACY snapshot check: fails on the current map; not part of the gate.
# See scripts/tests/README.md.
extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var court=load("res://scenes/barangay_court.tscn").instantiate()
 root.add_child(court)
 assert(not court.has_node("CourtRoof"))
 assert(court.find_children("UpperRoofSupport","MeshInstance3D",true,false).is_empty())
 var architecture=court.get_node("Architecture")
 var pillars=0
 for post in architecture.get_children():
  if not "Pillar" in String(post.name):continue
  pillars+=1
  assert(post.get_node("CreamShaft").mesh.size==Vector3(.56,1.3,.56))
  assert(post.get_node("TopCap").mesh.size==Vector3(.64,.1,.64))
  var white=post.get_node("CreamShaft").material_override
  var blue=post.get_node("BluePedestal").material_override
  assert(white.get_shader_parameter("tint")!=blue.get_shader_parameter("tint"))
  var joined=false
  for wall in architecture.get_children():
   if not "Wall" in String(wall.name):continue
   var v=wall.get_node("PaintedSurface")
   var bounds: AABB=v.global_transform*v.get_aabb()
   var post_bounds: AABB=post.get_node("CreamShaft").global_transform*post.get_node("CreamShaft").get_aabb()
   if bounds.intersects(post_bounds):joined=true
  assert(joined,"Pillar must intersect a wall without a gap: "+str(post.name))
 assert(pillars==15)
 for name in ["BarangayStage","StageStep0","StageStep1","StageStep2"]:
  var m=architecture.get_node(name+"/PaintedSurface").material_override
  assert(m.shader.resource_path=="res://shaders/aged_stage.gdshader")
  assert(m.get_shader_parameter("wood_texture")!=null)
 var zones=court.get_node("JailZones")
 assert(zones.find_children("*","StaticBody3D",true,false).is_empty())
 assert(zones.find_children("*","Area3D",true,false).size()==2)
 var holograms=0
 for mesh in zones.find_children("*","MeshInstance3D",true,false):
  assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
  if mesh.material_override is ShaderMaterial:
   assert(mesh.material_override.shader.resource_path=="res://shaders/holographic_jail.gdshader")
   holograms+=1
 assert(holograms==8)
 print("SAVED SCENE VERIFIED: all 15 slim pillars intersect walls; two-color materials; textured wooden platform + 3 steps; 8 non-solid hologram faces; no court roof/supports")
 court.free();quit()
