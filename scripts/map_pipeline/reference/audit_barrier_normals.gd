extends SceneTree
func _initialize():call_deferred("audit")
func audit():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court)
 var sample=BoxMesh.new();var arrays=sample.surface_get_arrays(0)
 var verts=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
 var ia=indices[0];var ib=indices[1];var ic=indices[2]
 print("BOX winding dot normal: ",(verts[ib]-verts[ia]).cross(verts[ic]-verts[ia]).dot(normals[ia]))
 for n in court.find_children("ClosedPaintedSurface","MeshInstance3D",true,false):
  if not "OrangeBleacherSafetyWall" in str(n.get_path()):continue
  arrays=n.mesh.surface_get_arrays(0);verts=arrays[Mesh.ARRAY_VERTEX];normals=arrays[Mesh.ARRAY_NORMAL]
  var wrong=0;var right=0
  for i in range(0,verts.size(),3):
   var dot=(verts[i+1]-verts[i]).cross(verts[i+2]-verts[i]).dot(normals[i])
   if dot>0.:wrong+=1
   elif dot<0.:right+=1
   if normals[i].y>.5:print(n.get_parent().name," top normal ",normals[i]," winding dot ",dot)
  print(n.get_parent().name," opposite winding ",wrong," correct ",right)
 var parent=court.get_node("StreetDetails/RoadsideConcreteBarrier6")
 for n in parent.get_children():print(n.name," ",n.transform)
 court.free();await process_frame;quit()
