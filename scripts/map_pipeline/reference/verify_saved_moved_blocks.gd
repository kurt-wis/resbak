extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court)
 await physics_frame;await physics_frame
 var entries=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/moved_concrete_blocks.json"))
 var parent=court.get_node("StreetDetails/RoadsideConcreteBarrier6")
 for i in range(entries.size()):
  var visual=court.get_node(entries[i].mesh_path)
  assert(visual.transform==str_to_var(entries[i].transform),"Moved position/rotation must stay exact")
  var col=parent.get_node("CollisionShape3D" if i==0 else "MovedBlockCollision2")
  var expected=visual.mesh.get_faces();var actual=col.shape.get_faces()
  assert(expected.size()==actual.size())
  for vertex in range(expected.size()):assert((visual.transform*expected[vertex]).is_equal_approx(actual[vertex]))
  var center=visual.global_transform*Vector3(0,.65,0);var across=visual.global_transform.basis.z.normalized()
  var query=PhysicsRayQueryParameters3D.create(center+across*.7,center-across*.7)
  var hit=root.world_3d.direct_space_state.intersect_ray(query)
  assert(not hit.is_empty() and hit.collider==parent)
  assert(parent.shape_owner_get_owner(parent.shape_find_owner(hit.shape))==col)
 assert(court.get_node("StreetDetails/RoadsideConcreteBarrier/CollisionShape3D").disabled)
 for visual in court.find_children("ClosedPaintedSurface","MeshInstance3D",true,false):
  var arrays=visual.mesh.surface_get_arrays(0);var v=arrays[Mesh.ARRAY_VERTEX];var n=arrays[Mesh.ARRAY_NORMAL];var ids=arrays[Mesh.ARRAY_INDEX]
  if ids==null or ids.is_empty():
   ids=PackedInt32Array()
   for i in range(v.size()):ids.append(i)
  for i in range(0,ids.size(),3):assert((v[ids[i+1]]-v[ids[i]]).cross(v[ids[i+2]]-v[ids[i]]).dot(n[ids[i]])<=.000001)
 print("PASSED: both saved moved blocks collide at their exact transforms; no ghost collision at old location; all closed concrete faces point outward")
 court.free();await process_frame;quit()

