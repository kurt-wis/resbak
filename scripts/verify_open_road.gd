extends "res://scripts/verify_reference_map.gd"
func verify():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 var court=scene.get_node("BarangayCourt");var homes=court.get_node("StreetDetails")
 assert(court.get_meta("reference_house_count")==0)
 assert(homes.find_children("BarangayHouse*","Node",true,false).is_empty())
 assert(homes.find_children("CorrugatedRoof*","Node",true,false).is_empty())
 assert(homes.find_children("RoadsideConcreteBarrier*","StaticBody3D",false,false).size()==31)
 assert(homes.find_children("ZebraCrossing*","MeshInstance3D",false,false).size()==22)
 for x in [-15.,0.,15.]:
  var p:Vector3=await walk(scene.player,Vector3(x,.1,24.),Vector3(0,0,3),110)
  print("FAR ROAD BLOCKS ",x,": ",p)
  assert(p.z<27.3 and p.z>26.,"Road sidewalk accessible; barrier must stop walking through")
 for side in [-1,1]:
  var p:Vector3=await walk(scene.player,Vector3(side*25.5,.1,22.),Vector3(side*3,0,0),90)
  print("ROAD END ",side,": ",p)
  assert(absf(p.x)<27.,"Road end barrier must block movement")
 print("PASSED: zero houses or house roofs; 31 concrete barriers; full-road crossings; sidewalk access and road boundaries")
 scene.free();await process_frame;quit()

