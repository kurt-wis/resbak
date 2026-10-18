extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court)
 await physics_frame
 var arch=court.get_node("Architecture")
 var seats=0
 for tier in arch.get_children():
  if not String(tier.name).begins_with("BleacherTier"):continue
  for seat in tier.get_children():
   if not seat is MeshInstance3D:continue
   var bounds=Transform3D(Basis.IDENTITY,tier.position+seat.position)*seat.get_aabb()
   for cheek in arch.get_children():
    if not String(cheek.name).begins_with("BleacherSideOrangeCheek") and not String(cheek.name).begins_with("BleacherAisleOrangeCheek"):continue
    var cb=cheek.get_node("ClosedPaintedSurface").get_aabb()
    assert(not bounds.intersects(cb),"Seating intersects orange cheek: "+str(tier.name))
   seats+=1
 assert(seats==42)
 var rear=arch.get_node("RearConcreteBase")
 var rear_front=rear.position.z+rear.get_node("PaintedSurface").get_aabb().end.z
 for landing in arch.find_children("BleacherRearLanding*","StaticBody3D",false,false):
  var edge=landing.position.z+landing.get_node("PaintedSurface").get_aabb().position.z
  assert(absf(edge-rear_front)<.001,"Rear landing must join rear wall")
 var first=arch.get_node("BleacherTier")
 assert(absf(first.position.z+11.05)<.001)
 assert(first.position.z+.43 < -10.6,"Keep walkway between court and stands")
 var net=arch.get_node("CenterCourtVolleyballNet")
 assert(net.material_override.shader.resource_path.ends_with("reference_volleyball_net.gdshader"))
 assert(absf(net.position.y-net.mesh.size.y*.5-2.93)<.001)
 print("VERIFIED: 42 seating sections clear side covers; both rear landings join wall; widened front walkway; elevated square-mesh volleyball net")
 court.free();await process_frame;quit()
