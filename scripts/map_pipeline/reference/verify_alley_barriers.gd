extends "res://scripts/map_pipeline/reference/verify_reference_map.gd"
func verify():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 var court=scene.get_node("BarangayCourt");var homes=court.get_node("StreetDetails")
 var barriers=homes.find_children("RoadsideConcreteBarrier*","StaticBody3D",false,false)
 assert(barriers.size()==6)
 for barrier in barriers:
  var visual=barrier.get_node("ContinuousConcreteSurface")
  var bounds=visual.mesh.get_aabb()
  assert(absf(bounds.size.x-2.45)<.001 and absf(bounds.size.z-.74)<.001)
  assert(absf(bounds.size.y-1.14)<.001)
 var blockers=homes.find_children("SideAlleyBoundary*","StaticBody3D",false,false)
 assert(blockers.size()==2)
 for blocker in blockers:assert(blocker.find_children("*","MeshInstance3D",false,false).is_empty())
 for side in [-1,1]:
  for x in [25.7,27.,28.4]:
   var p:Vector3=await walk(scene.player,Vector3(side*x,.3,16.6),Vector3(0,0,-4),65)
   print("ALLEY ",side*x,": ",p)
   assert(p.z>14.8,"Alley entry must be blocked across its full width")
 var arch=court.get_node("Architecture")
 assert(arch.find_children("BleacherAisleOrangeCheek*","StaticBody3D",false,false).is_empty())
 assert(arch.find_children("BleacherSeating*","StaticBody3D",false,false).size()==4)
 assert(arch.find_children("BleacherAisleStair*","Node3D",false,false).size()==4)
 assert(arch.find_children("BleacherFrontLip*","MeshInstance3D",false,false).is_empty())
 print("PASSED: 6 shaped concrete barriers; both alleys blocked across full width; continuous seating/stairs; no old overlapping cheek or raised lip pieces")
 scene.free();await process_frame;quit()
