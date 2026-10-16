extends SceneTree
func _initialize():call_deferred("fix")
func snapshot(court: Node3D)->Dictionary:
 var result={}
 for node in court.find_children("*","Node3D",true,false):
  if not node is CollisionShape3D:result[str(court.get_path_to(node))]=node.transform
 return result
func fix():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court)
 var before=snapshot(court);var corrected_faces=0;var corrected_meshes=0
 for visual in court.find_children("*","MeshInstance3D",true,false):
  if not visual.material_override is ShaderMaterial:continue
  if visual.material_override.shader.resource_path!="res://shaders/reference_closed_concrete.gdshader":continue
  var geometry=ArrayMesh.new();var changed=0
  for surface in range(visual.mesh.get_surface_count()):
   var arrays=visual.mesh.surface_get_arrays(surface);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
   var indices=arrays[Mesh.ARRAY_INDEX]
   if indices==null or indices.is_empty():
    indices=PackedInt32Array()
    for i in range(vertices.size()):indices.append(i)
   for i in range(0,indices.size(),3):
    var ia=indices[i];var ib=indices[i+1];var ic=indices[i+2]
    var normal=(normals[ia]+normals[ib]+normals[ic]).normalized()
    if (vertices[ib]-vertices[ia]).cross(vertices[ic]-vertices[ia]).dot(normal)>0.0000001:
     indices[i+1]=ic;indices[i+2]=ib;changed+=1
   arrays[Mesh.ARRAY_INDEX]=indices;geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  if changed>0:
   visual.mesh=geometry;corrected_faces+=changed;corrected_meshes+=1
 var parent=court.get_node("StreetDetails/RoadsideConcreteBarrier6")
 var moved=[]
 for name in ["ContinuousConcreteSurface","ContinuousConcreteSurface2"]:
  var visual=parent.get_node(name)
  var col=parent.get_node_or_null("CollisionShape3D" if moved.is_empty() else "MovedBlockCollision2")
  if col==null:
   col=CollisionShape3D.new();col.name="MovedBlockCollision2";parent.add_child(col);col.owner=court
  var faces=visual.mesh.get_faces()
  for vertex in range(faces.size()):faces[vertex]=visual.transform*faces[vertex]
  var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);shape.backface_collision=true;col.shape=shape
  col.transform=Transform3D.IDENTITY;col.disabled=false
  moved.append({"mesh_path":str(court.get_path_to(visual)),"transform":var_to_str(visual.transform)})
 # The original left block's visual was moved under the right block's parent.
 var old=court.get_node("StreetDetails/RoadsideConcreteBarrier")
 if old.find_children("*","MeshInstance3D",false,false).is_empty():old.get_node("CollisionShape3D").disabled=true
 assert(snapshot(court)==before,"No existing visible object may move or rotate")
 var packed=PackedScene.new();assert(packed.pack(court)==OK)
 assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 var data=FileAccess.open("res://assets/environment/moved_concrete_blocks.json",FileAccess.WRITE)
 data.store_string(JSON.stringify(moved,"  "));data.close()
 await physics_frame;await physics_frame
 for i in range(moved.size()):
  var visual=court.get_node(moved[i].mesh_path)
  var col=parent.get_node("CollisionShape3D" if i==0 else "MovedBlockCollision2")
  assert(col.transform==Transform3D.IDENTITY)
  var center=visual.global_transform*Vector3(0,.65,0)
  var across=visual.global_transform.basis.z.normalized()
  var query=PhysicsRayQueryParameters3D.create(center+across*.7,center-across*.7)
  var hit=root.world_3d.direct_space_state.intersect_ray(query)
  assert(not hit.is_empty(),"Moved block must have collision")
  assert(hit.collider==parent,"Ray must hit moved block body")
  var owner_id=parent.shape_find_owner(hit.shape)
  assert(parent.shape_owner_get_owner(owner_id)==col,"Collision must belong to the matching moved mesh")
  print("MOVED BLOCK COLLISION VERIFIED: ",visual.name," ",visual.global_position)
 var saved=load_saved()
 assert(snapshot(saved)==before,"All saved visible object transforms remain unchanged")
 print("FIXED: ",corrected_faces," reversed triangles across ",corrected_meshes," concrete meshes; both moved blocks collide; all existing object transforms preserved")
 saved.free();court.free();await process_frame;quit()
func load_saved()->Node3D:
 return ResourceLoader.load("res://scenes/barangay_court.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()

