extends SceneTree
var court: Node3D
func _initialize():
 call_deferred("build")
func paint(hex: String)->ShaderMaterial:
 var m:=ShaderMaterial.new()
 m.shader=load("res://shaders/painted_architecture.gdshader")
 m.set_shader_parameter("painted_surface",load("res://assets/environment/painted_concrete_tile.res"))
 m.set_shader_parameter("painted_surface",load("res://assets/environment/painted_concrete_tile.res"))
 m.set_shader_parameter("tint",Color(hex))
 return m
func surface(hex: String)->ShaderMaterial:
 var m:=ShaderMaterial.new()
 m.shader=load("res://shaders/neighborhood_surface.gdshader")
 m.set_shader_parameter("painted_surface",load("res://assets/environment/painted_concrete_tile.res"))
 m.set_shader_parameter("tint",Color(hex))
 return m
func box(parent: Node3D,n: String,p: Vector3,s: Vector3,m: Material)->MeshInstance3D:
 var v:=MeshInstance3D.new()
 v.name=n; v.position=p
 var mesh:=BoxMesh.new(); mesh.size=s
 v.mesh=mesh; v.material_override=m
 parent.add_child(v); v.owner=court
 return v
func build():
 court=load("res://scenes/barangay_court.tscn").instantiate()
 root.add_child(court); court.scene_file_path=""
 if court.has_node("NeighborhoodSurroundings"): court.get_node("NeighborhoodSurroundings").free()
 for pillar in court.get_node("Architecture").get_children():
  if pillar.has_node("WeatheredBlueLowerPaint"): pillar.get_node("WeatheredBlueLowerPaint").free()
 var white:=paint("dedbd2")
 var blue:=paint("647f98")
 var wall:=paint("bbbcc2")
 for pillar in court.get_node("Architecture").get_children():
  if "Pillar" in String(pillar.name):
   pillar.get_node("CreamShaft").material_override=white
   pillar.get_node("TopCap").material_override=white
   pillar.get_node("BluePedestal").material_override=blue
   var lower:=box(pillar,"WeatheredBlueLowerPaint",Vector3(0,.945,0),Vector3(.948,.61,.948),blue)
   lower.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  elif "Wall" in String(pillar.name) and pillar.has_node("PaintedSurface"):
   pillar.get_node("PaintedSurface").material_override=wall
 var walkway=court.get_node("StreetDetails/RaisedSidewalk")
 for child in walkway.get_children():
  if String(child.name).begins_with("Drain"):
   child.free()
 var rust:=surface("514945")
 var iron:=surface("3b4146")
 var hole:=surface("121a20")
 for x in [-12,0,12]:
  box(walkway,"DrainDarkRecess"+str(x),Vector3(x,.164,12),Vector3(1.22,.008,.47),hole)
  for z in [11.755,12.245]:
   box(walkway,"WornDrainRim",Vector3(x,.17, z),Vector3(1.3,.018,.045),rust)
  for i in range(9):
   box(walkway,"IronDrainBar",Vector3(x-.55+i*.138,.176,12),Vector3(.052,.012,.43),iron)
 var outside:=Node3D.new(); outside.name="NeighborhoodSurroundings"
 court.add_child(outside); outside.owner=court
 var asphalt:=surface("55545b")
 box(outside,"SurroundingStreet",Vector3(0,-.12,1),Vector3(86,.16,78),asphalt)
 var concrete:=surface("85838a")
 for side in [-1,1]:
  box(outside,"OutsideFootpath",Vector3(side*22,.012,0),Vector3(3.3,.04,45),concrete)
 box(outside,"BackLane",Vector3(0,.012,-15),Vector3(43,.04,4),concrete)
 var random:=RandomNumberGenerator.new(); random.seed=214
 var roof:=surface("6a6974")
 var shutter:=surface("4d5662")
 var colors: Array[String]=["b0a596","939ea5","9b9e8f","b49a88"]
 for side in [-1,1]:
  for i in range(6):
   var x:=float(side)*27.5
   var z: float=-20.0+i*8.0
   var h:=random.randf_range(2.8,4.5)
   box(outside,"BarangayHouse",Vector3(x,h*.5,z),Vector3(6,h,6.5),paint(colors[i%4]))
   box(outside,"CorrugatedEave",Vector3(x,h+.10,z),Vector3(6.6,.18,7),roof)
   box(outside,"ClosedShopShutter",Vector3(x-side*3.02,1.15,z),Vector3(.06,2.1,2.4),shutter)
   for bar in range(7):
    box(outside,"ShutterSeam",Vector3(x-side*3.06,.3+bar*.28,z),Vector3(.04,.035,2.4),iron)
 for i in range(6):
  var x: float=-21.0+i*8.0
  box(outside,"BackNeighborhoodHouse",Vector3(x,1.7,-23),Vector3(6,3.4,6),paint(colors[i%4]))
  box(outside,"BackHouseRoof",Vector3(x,3.5,-23),Vector3(6.6,.2,6.6),roof)
 # Opaque flat water polygons avoid expensive reflections and transparent sorting.
 var water:=surface("626f79")
 for i in range(22):
  var x: float=random.randf_range(-24,24)
  var z: float=random.randf_range(-18,21)
  if absf(x)<20.5 and z<16.0 and z> -12.5:
   x=signf(x)*random.randf_range(21,23.5)
  var vertices:=PackedVector3Array()
  var scale_x:=random.randf_range(.5,1.5)
  var scale_z:=random.randf_range(.3,.9)
  for j in range(12):
   var a:=TAU*j/12.0
   vertices.append(Vector3(cos(a)*scale_x*random.randf_range(.8,1.1),0,sin(a)*scale_z*random.randf_range(.8,1.1)))
  var indices:=PackedInt32Array()
  for j in range(1,11): indices.append_array([0,j+1,j])
  var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_INDEX]=indices
  var normals:=PackedVector3Array(); normals.resize(12); normals.fill(Vector3.UP)
  arrays[Mesh.ARRAY_NORMAL]=normals
  var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var puddle:=MeshInstance3D.new(); puddle.name="ShallowStreetPuddle"; puddle.mesh=mesh
  puddle.material_override=water; puddle.position=Vector3(x,.04,z)
  puddle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  outside.add_child(puddle); puddle.owner=court
 for decoration in outside.find_children("*","MeshInstance3D",true,false):
  decoration.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for frame in range(3): await RenderingServer.frame_post_draw
 var packed:=PackedScene.new(); assert(packed.pack(court)==OK)
 assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 print("NEIGHBORHOOD: 15 two-color pillars, 18 simple buildings, 22 low-poly puddles, recessed iron drains; existing litter preserved")
 quit()


