extends "res://scripts/map_pipeline/reference/verify_reference_map.gd"
func verify():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 var court=scene.get_node("BarangayCourt");var homes=court.get_node("StreetDetails")
 var poles=homes.find_children("PerimeterUtilityPole*","MeshInstance3D",false,false)
 assert(poles.size()==15 and court.get_meta("perimeter_pole_count")==15)
 var positions=[]
 for pole in poles:
  var p=pole.position
  assert(absf(absf(p.x)-29.6)<.001 or absf(p.z+20.4)<.001 or absf(p.z-29.4)<.001,"Pole must follow perimeter")
  assert(not positions.has(Vector2(p.x,p.z)),"No duplicate poles")
  positions.append(Vector2(p.x,p.z))
 assert(homes.find_children("ForegroundUtilityPole*","MeshInstance3D",false,false).is_empty())
 assert(homes.find_children("UtilityPole*","MeshInstance3D",false,false).is_empty())
 assert(homes.find_children("ForegroundSaggingWire*","MeshInstance3D",false,false).is_empty())
 assert(homes.find_children("RoadsideConcreteBarrier*","StaticBody3D",false,false).size()==31)
 for side in [-1,1]:
  var p:Vector3=await walk(scene.player,Vector3(side*25.7,.3,15.55),Vector3(side*3,0,0),90)
  print("CORNER BARRIER ",side,": ",p)
  assert(absf(p.x)<27.,"Concrete barrier must block each marked corner")
 var stage=court.get_node("Architecture/StagePlatform/PaintedSurface")
 assert(stage.material_override.shader.resource_path.ends_with("reference_stage_timber.gdshader"))
 print("PASSED: 15 unique perimeter poles; no old road poles/cables; both new corners block movement; 31 concrete blocks; textured matte timber stage")
 scene.free();await process_frame;quit()
