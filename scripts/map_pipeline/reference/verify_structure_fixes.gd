extends SceneTree
func _initialize():call_deferred("verify")
func key(v: Vector3)->String:return "%d,%d,%d"%[roundi(v.x*100000),roundi(v.y*100000),roundi(v.z*100000)]
func closed(mesh: Mesh)->bool:
 var faces=mesh.get_faces();var edges={}
 for i in range(0,faces.size(),3):
  for j in range(3):
   var a=key(faces[i+j]);var b=key(faces[i+(j+1)%3]);var pair=a+"|"+b if a<b else b+"|"+a
   edges[pair]=edges.get(pair,0)+1
 for count in edges.values():
  if count!=2:return false
 return true
func verify():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court)
 await physics_frame
 var arch=court.get_node("Architecture");var filled=0;var wedges=0;var front=0;var sides=0
 for n in arch.get_children():
  if String(n.name).begins_with("FilledEntranceStep"):
   filled+=1
   var bounds=n.global_transform*n.get_aabb()
   assert(absf(bounds.position.y-.2)<.0001,"Entrance steps must extend down to the sidewalk")
  if n.has_node("ClosedPaintedSurface"):
   assert(closed(n.get_node("ClosedPaintedSurface").mesh),"Concrete wedge must be closed: "+str(n.name));wedges+=1
  if String(n.name).begins_with("FrontConcreteRetainingWall"):
   var bound=n.get_node("PaintedSurface").get_aabb();assert(absf(n.position.y+bound.end.y-2.3)<.0001);front+=1
  if String(n.name).begins_with("SideConcreteBase"):
   var bound=n.get_node("PaintedSurface").get_aabb();assert(absf(n.position.y+bound.end.y-2.3)<.0001);sides+=1
 assert(filled==24);assert(front==4 and sides==2);assert(wedges>=18)
 var ring=court.get_node("StreetDetails/ContinuousRoundedSidewalk/ClosedPaintedSurface")
 assert(closed(ring.mesh),"Sidewalk ring must have no open edges")
 var space=root.world_3d.direct_space_state;var hits=0
 var samples=[]
 for i in range(55):
  var x=lerpf(-26.2,26.2,i/54.)
  samples.append(Vector3(x,.2,17.5));samples.append(Vector3(x,.2,-18.2))
 for i in range(37):
  var z=lerpf(-18.2,17.5,i/36.)
  samples.append(Vector3(-26.2,.2,z));samples.append(Vector3(26.2,.2,z))
 for point in samples:
  var world=point*court.scale
  var query=PhysicsRayQueryParameters3D.create(world+Vector3.UP*.6,world-Vector3.UP*.4)
  var hit=space.intersect_ray(query)
  assert(not hit.is_empty(),"Sidewalk gap at "+str(point))
  assert(absf(hit.position.y-.2)<.025,"Sidewalk height mismatch at "+str(point))
  hits+=1
 var barriers=court.get_node("StreetDetails").find_children("RoadsideConcreteBarrier*","StaticBody3D",false,false)
 assert(barriers.size()==6)
 print("STRUCTURE VERIFIED: ",filled," full-depth entrance steps; ",wedges," closed concrete wedges; front/side base heights equal; watertight rounded sidewalk with ",hits," collision samples; 6 roadside barriers")
 court.free();await process_frame;quit()
