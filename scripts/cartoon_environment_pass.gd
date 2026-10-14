extends SceneTree
func _initialize():call_deferred("apply")
func apply():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court);court.scene_file_path=""
 var wood=ShaderMaterial.new();wood.shader=load("res://shaders/cartoon_stage_wood.gdshader")
 for node in court.get_node("Architecture").get_children():
  if node.name=="BarangayStage" or String(node.name).begins_with("StageStep"):node.get_node("PaintedSurface").material_override=wood
 var ground=ShaderMaterial.new();ground.shader=load("res://shaders/dusty_puddled_lane.gdshader")
 var surroundings=court.get_node("NeighborhoodSurroundings")
 for node in surroundings.get_children():
  if String(node.name).begins_with("ShallowStreetPuddle"):node.free()
  elif node.name=="SurroundingStreet" or "Footpath" in String(node.name) or node.name=="BackLane":node.material_override=ground
 var lane=MeshInstance3D.new();lane.name="DustyFrontAlley"
 var plane=PlaneMesh.new();plane.size=Vector2(40,4.8);lane.mesh=plane
 lane.position=Vector3(0,.022,15.5);lane.material_override=ground
 lane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 surroundings.add_child(lane);lane.owner=court
 var graffiti=Node3D.new();graffiti.name="PaintedWallGraffiti";court.add_child(graffiti);graffiti.owner=court
 for data in [[Vector3(-14,.912,11),Vector3(-90,0,0),Color("797989")],[Vector3(3,.912,11),Vector3(-90,0,0),Color("988370")],[Vector3(-19.79,1.112,1),Vector3(-90,90,0),Color("76858d")],[Vector3(19.79,1.112,5),Vector3(-90,90,0),Color("a28b76")],[Vector3(-14,.7,10.8),Vector3.ZERO,Color("727b8b")],[Vector3(3,.7,10.8),Vector3.ZERO,Color("9d806b")]]:
  var v=MeshInstance3D.new();v.name="FadedSprayTag"
  var q=QuadMesh.new();q.size=Vector2(2.1,.36);v.mesh=q
  v.position=data[0];v.rotation_degrees=data[1]
  var m=ShaderMaterial.new();m.shader=load("res://shaders/wall_graffiti.gdshader");m.set_shader_parameter("paint_color",data[2]);v.material_override=m
  v.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  graffiti.add_child(v);v.owner=court
 for frame in range(3):await RenderingServer.frame_post_draw
 assert(graffiti.get_child_count()==6)
 var packed=PackedScene.new();assert(packed.pack(court)==OK);assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 print("APPLIED: dusty puddled outside lanes including nearby front alley, six faded wall tags, shared cartoon planks on stage/stairs")
 court.free();await process_frame;quit()
