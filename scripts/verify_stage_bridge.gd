extends "res://scripts/verify_reference_map.gd"
func verify():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 var court=scene.get_node("BarangayCourt");var arch=court.get_node("Architecture")
 var aisles=court.get_meta("bleacher_aisles")
 assert(aisles==[-16.,-5.3,5.3,16.],"Stair positions must mirror")
 for tier in arch.get_children():
  if not String(tier.name).begins_with("BleacherTier"):continue
  for seat in tier.get_children():
   if seat is MeshInstance3D:assert(seat.mesh.size.x>.4,"No narrow seat slivers beside aisles")
 var body=scene.player
 for x in aisles:
  var p:Vector3=await walk(body,Vector3(x,1.6,-10.2),Vector3(0,0,-3),140)
  print("UPPER LANDING ",x,": ",p)
  assert(p.y>4. and p.z<-15.8,"Stairs must reach rear walkway")
 var p:Vector3=await walk(body,Vector3(-18,4.15,-16.2),Vector3(4,0,0),540)
 print("BRIDGE LEFT TO RIGHT: ",p)
 assert(p.x>17. and absf(p.y-4.09)<.05,"Walk across stage bridge to opposite stand")
 p=await walk(body,Vector3(18,4.15,-16.2),Vector3(-4,0,0),540)
 print("BRIDGE RIGHT TO LEFT: ",p)
 assert(p.x< -17. and absf(p.y-4.09)<.05,"Walk back across bridge")
 var roof=arch.get_node("StageCanopy")
 assert(roof.position.z-roof.mesh.size.z*.5> -15.6,"Roof must clear elevated route")
 print("PASSED: mirrored stairs, no seat slivers, all four aisles reach top; bridge walkable in both directions; roof clearance")
 scene.free();await process_frame;quit()
