extends "res://scripts/verify_reference_map.gd"
func verify():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 var arch=scene.get_node("BarangayCourt/Architecture")
 assert(arch.find_children("OrangeBleacherSafetyWall*","StaticBody3D",false,false).size()==4)
 assert(arch.find_children("OuterRearSafetyReturn*","StaticBody3D",false,false).size()==2)
 for side in [-1,1]:
  for z in [-11.6,-13.,-14.6]:
   var start:Vector3=await walk(scene.player,Vector3(side*22.3,4.2,z),Vector3.ZERO,65)
   var p:Vector3=await walk(scene.player,start,Vector3(side*3,0,0),80)
   print("OUTER GUARD ",side," ",z,": ",p)
   assert(absf(p.x)<23.,"Outer guard must prevent falling off seating")
   start=await walk(scene.player,Vector3(side*5.3,4.2,z),Vector3.ZERO,65)
   p=await walk(scene.player,start,Vector3(-side*3,0,0),80)
   print("INNER GUARD ",side," ",z,": ",p)
   assert(absf(p.x)>5.,"Inner guard must prevent falling toward stage")
 print("PASSED: all four orange guards block lateral movement at three heights; both rear returns present")
 scene.free();await process_frame;quit()

