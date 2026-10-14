extends SceneTree
func _initialize(): call_deferred("refine")
func paint(hex: String)->ShaderMaterial:
 var m=ShaderMaterial.new(); m.shader=load("res://shaders/painted_architecture.gdshader")
 m.set_shader_parameter("painted_surface",load("res://assets/environment/painted_concrete_tile.png"))
 m.set_shader_parameter("tint",Color(hex)); return m
func box(parent: Node3D,n: String,p: Vector3,s: Vector3,m: Material,owner_root: Node)->MeshInstance3D:
 var v=MeshInstance3D.new(); v.name=n;v.position=p
 var b=BoxMesh.new();b.size=s;v.mesh=b;v.material_override=m
 parent.add_child(v);v.owner=owner_root; return v
func refine():
 var court=load("res://scenes/barangay_court.tscn").instantiate()
 root.add_child(court);court.scene_file_path=""
 if court.has_node("CourtRoof"):court.get_node("CourtRoof").free()
 var white=paint("b9b6ad");var blue=paint("596d80");var wall=paint("a1a0a4")
 var wood=ShaderMaterial.new();wood.shader=load("res://shaders/aged_stage.gdshader")
 wood.set_shader_parameter("wood_texture",load("res://assets/environment/stage_wood.png"))
 var architecture=court.get_node("Architecture")
 var pillars=0;var wooden=0
 for node in architecture.get_children():
  if "Pillar" in String(node.name):
   pillars+=1
   if String(node.name).begins_with("Side"):node.position.x=signf(node.position.x)*19.8
   elif String(node.name).begins_with("Rear"):node.position.z=-11.85
   elif String(node.name).begins_with("Entrance"):node.position.z=11.0
   for child in node.get_children():child.free()
   box(node,"BluePedestal",Vector3(0,.2,0),Vector3(.56,.4,.56),blue,court)
   box(node,"CreamShaft",Vector3(0,1.05,0),Vector3(.56,1.3,.56),white,court)
   box(node,"TopCap",Vector3(0,1.75,0),Vector3(.64,.1,.64),white,court)
   var collision=CollisionShape3D.new();collision.name="JoinedPillarCollision"
   var shape=BoxShape3D.new();shape.size=Vector3(.64,1.8,.64)
   collision.shape=shape;collision.position.y=.9;node.add_child(collision);collision.owner=court
  elif "Wall" in String(node.name) and node.has_node("PaintedSurface"):
   node.get_node("PaintedSurface").material_override=wall
   # End strokes made intersections read as detached blocks. The wall now enters the aligned post.
   for child in node.get_children():
    if String(child.name).begins_with("EndEdge"):child.free()
  elif node.name=="BarangayStage" or String(node.name).begins_with("StageStep"):
   node.get_node("PaintedSurface").material_override=wood;wooden+=1
 var zones=court.get_node("JailZones")
 for child in zones.get_children():
  if child is Area3D:continue
  child.free()
 for data in [["YellowJail",Color("ffd34f")],["PurpleJail",Color("c75eff")]]:
  var zone=zones.get_node(data[0])
  var pos: Vector3=zone.position;pos.y=0
  var m=ShaderMaterial.new();m.shader=load("res://shaders/holographic_jail.gdshader");m.set_shader_parameter("team_color",data[1])
  var glow=StandardMaterial3D.new();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  glow.albedo_color=data[1];glow.emission_enabled=true;glow.emission=data[1];glow.emission_energy_multiplier=.5
  for side in [-1,1]:
   var h=box(zones,"HologramSide",pos+Vector3(side*2,.65,0),Vector3(.008,1.3,3.3),m,court)
   h.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   box(zones,"ProjectedGroundLine",pos+Vector3(side*2,.055,0),Vector3(.035,.008,3.3),glow,court).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   h=box(zones,"HologramEnd",pos+Vector3(0,.65,side*1.65),Vector3(4,1.3,.008),m,court)
   h.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   box(zones,"ProjectedGroundLine",pos+Vector3(0,.055,side*1.65),Vector3(4,.008,.035),glow,court).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for frame in range(3):await RenderingServer.frame_post_draw
 assert(pillars==15);assert(wooden==4)
 assert(not court.has_node("CourtRoof"))
 assert(zones.find_children("*","StaticBody3D",true,false).is_empty())
 assert(zones.find_children("*","Area3D",true,false).size()==2)
 for batch in court.get_node("StreetLitter").get_children():assert(batch.multimesh.buffer.size()>0)
 var packed=PackedScene.new();assert(packed.pack(court)==OK)
 assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 print("VERIFIED: 15 slim aligned two-color posts; 4 wood stage surfaces; 2 non-solid holographic zones; roof and supports removed; litter preserved")
 court.free();await process_frame;quit()
