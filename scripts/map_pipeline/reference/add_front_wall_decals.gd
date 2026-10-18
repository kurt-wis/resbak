extends SceneTree
func _initialize():call_deferred("add_decals")
func transforms(court: Node3D)->Dictionary:
 var result={}
 for node in court.find_children("*","Node3D",true,false):result[str(court.get_path_to(node))]=node.transform
 return result
func add_decals():
 var court=load("res://scenes/barangay_court.tscn").instantiate();root.add_child(court)
 var before=transforms(court)
 assert(not court.has_node("FrontWallDecals"),"Do not duplicate installed decals")
 var materials={}
 for key in ["bawal_umihi_dito","malabanan_123_45_67","meme_67_basketball"]:
  var img=Image.load_from_file("res://assets/decals/"+key+".png")
  assert(img.get_pixel(0,0).a==0.,"Decal background must be transparent")
  img.resize(768,512,Image.INTERPOLATE_LANCZOS);img.generate_mipmaps()
  var tex=ImageTexture.create_from_image(img)
  assert(ResourceSaver.save(tex,"res://assets/decals/"+key+".res")==OK)
  var mat=StandardMaterial3D.new();mat.resource_name=key
  mat.albedo_texture=load("res://assets/decals/"+key+".res")
  mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=.15
  mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1.;mat.metallic_specular=0.
  mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  materials[key]=mat
 var group=Node3D.new();group.name="FrontWallDecals";root.add_child(group)
 var layout=[
  ["BawalWarningLeft","bawal_umihi_dito",-22.4,1.18,3.2,1.75,0.],
  ["ServicePosterLeft","malabanan_123_45_67",-18.65,1.22,1.8,1.05,-.025],
  ["ServicePosterMidLeft","malabanan_123_45_67",-10.1,1.25,1.5,.875,.035],
  ["Meme67MidLeft","meme_67_basketball",-6.8,1.17,3.6,1.8,0.],
  ["BawalWarningMidRight","bawal_umihi_dito",5.2,1.18,3.2,1.75,0.],
  ["ServicePosterMidRight","malabanan_123_45_67",9.2,1.25,1.8,1.05,.025],
  ["Meme67Right","meme_67_basketball",20.,1.17,3.6,1.8,0.],
  ["ServicePosterRight","malabanan_123_45_67",23.7,1.25,1.5,.875,-.035]]
 for d in layout:
  var mesh=MeshInstance3D.new();mesh.name=d[0];var quad=QuadMesh.new();quad.size=Vector2(d[4],d[5])
  mesh.mesh=quad;mesh.material_override=materials[d[1]];mesh.position=Vector3(d[2],d[3],14.207);mesh.rotation.z=d[6]
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  group.add_child(mesh);mesh.owner=group
 var standalone=PackedScene.new();assert(standalone.pack(group)==OK)
 assert(ResourceSaver.save(standalone,"res://assets/decals/front_wall_decals.tscn")==OK)
 group.free()
 var installed=load("res://assets/decals/front_wall_decals.tscn").instantiate();court.add_child(installed);installed.owner=court
 for path in before:assert(court.get_node(path).transform==before[path],"Existing placement changed: "+path)
 var packed=PackedScene.new();assert(packed.pack(court)==OK)
 assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 assert(installed.get_child_count()==8)
 for decal in installed.get_children():
  assert(absf(decal.position.z-14.207)<.00001)
  assert(decal.position.y-decal.mesh.size.y/2.>0. and decal.position.y+decal.mesh.size.y/2.<2.3)
 print("INSTALLED: 8 lit alpha decals on the four front wall panels only; exact poster number 123-45-67; all existing transforms preserved")
 court.free();await process_frame;quit()
