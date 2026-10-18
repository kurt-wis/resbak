extends SceneTree
var map: Node3D
var arch: Node3D
var props: Node3D
var homes: Node3D
var rng=RandomNumberGenerator.new()
var cream: Material
var orange: Material
var steel: Material
var dark: Material
var white: Material
var paint_cache={}
var reference_layout: Dictionary
var roof_texture: Texture2D
var house_count=0
var entrance_centers=[-14.2,-.25,13.95]
var bleacher_setback=-1.65
var bleacher_aisles={-1:[-16.,-5.3],1:[5.3,16.]}
func _initialize():call_deferred("build")
func paint(hex: String,roof: float=0.)->ShaderMaterial:
 var palette={"a4835a":"b57957","b8b4a0":"b9b7aa","b58755":"b58d60","a39f8f":"a3a092","8d8778":"969182"}
 hex=palette.get(hex,hex)
 var key=hex+str(roof)
 if paint_cache.has(key):return paint_cache[key]
 var m=ShaderMaterial.new();m.shader=load("res://shaders/reference_paint.gdshader")
 m.set_shader_parameter("fine_texture",load("res://assets/environment/concrete.png"));m.set_shader_parameter("base_color",Color(hex));m.set_shader_parameter("stucco",1.0 if hex=="b58d60" else 0.0);m.set_shader_parameter("roof",roof);m.set_shader_parameter("wear_texture",load("res://assets/environment/painted_concrete_tile.png"));m.set_shader_parameter("roof_texture",roof_texture);paint_cache[key]=m;return m
func roof_paint(hex: String,axis: int)->ShaderMaterial:
 var key="roof_"+hex+str(axis)
 if paint_cache.has(key):return paint_cache[key]
 var m=paint(hex,1.).duplicate();m.set_shader_parameter("roof_axis",float(axis));paint_cache[key]=m;return m
func pin(name: String,height: float=1.5)->Vector3:
 var position=reference_layout["prop_positions"][name]
 return Vector3(position[0],height,position[1])
func group(name: String)->Node3D:
 var n=Node3D.new();n.name=name;map.add_child(n,true);n.owner=map;return n
func mesh(parent: Node3D,name: String,pos: Vector3,geometry: Mesh,material: Material)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=name;n.position=pos;n.mesh=geometry;n.material_override=material
 parent.add_child(n,true);n.owner=map;return n
func box(parent: Node3D,name: String,pos: Vector3,size: Vector3,material: Material,solid: bool=false)->Node3D:
 var b=BoxMesh.new();b.size=size
 if not solid:return mesh(parent,name,pos,b,material)
 var body=StaticBody3D.new();body.name=name;body.position=pos;parent.add_child(body,true);body.owner=map
 mesh(body,"PaintedSurface",Vector3.ZERO,b,material)
 var c=CollisionShape3D.new();var s=BoxShape3D.new();s.size=size;c.shape=s;body.add_child(c,true);c.owner=map
 return body
func rod(parent: Node3D,name: String,a: Vector3,b: Vector3,r: float,material: Material):
 var cy=CylinderMesh.new();cy.top_radius=r;cy.bottom_radius=r;cy.height=a.distance_to(b);cy.radial_segments=6
 var v=mesh(parent,name,(a+b)*.5,cy,material)
 var direction=(b-a).normalized();var axis=Vector3.UP.cross(direction)
 if axis.length()>.001:v.quaternion=Quaternion(Vector3.UP,direction)
 elif direction.y<0:v.rotation.x=PI
func line(parent: Node3D,name: String,points: Array,width: float,mat: Material):
 if name in ["CourtBoundary","HalfCourt","CenterCircle","BasketballKey","ThreePointArc","FreeThrowArc"]:
  var vertices=PackedVector3Array();var normals=PackedVector3Array();var indices=PackedInt32Array()
  for i in range(points.size()-1):
   var a: Vector3=points[i];var b: Vector3=points[i+1];var across=(b-a).normalized().cross(Vector3.UP)*width*.5
   var base=vertices.size();vertices.append_array([a-across,a+across,b+across,b-across]);normals.append_array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP]);indices.append_array([base,base+1,base+2,base,base+2,base+3])
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
  var geometry=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var flat_paint=StandardMaterial3D.new();flat_paint.albedo_color=Color("eee7cf");flat_paint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;flat_paint.cull_mode=BaseMaterial3D.CULL_DISABLED
  mesh(parent,name,Vector3.ZERO,geometry,flat_paint).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 else:
  for i in range(points.size()-1):rod(parent,name,points[i],points[i+1],width*.5,mat)
func fence(a: Vector3,b: Vector3,height: float=2.7):
 var length=Vector2(b.x-a.x,b.z-a.z).length();var count=int(ceil(length/3.6));var direction=(b-a).normalized()
 var horizontal=Vector3(direction.x,0,direction.z).normalized()
 var across=horizontal.cross(Vector3.UP)*.04
 for i in range(count):
  var start=a.lerp(b,float(i)/count);var end=a.lerp(b,float(i+1)/count)
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([start,end,end+Vector3.UP*height,start+Vector3.UP*height])
  arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([horizontal.cross(Vector3.UP),horizontal.cross(Vector3.UP),horizontal.cross(Vector3.UP),horizontal.cross(Vector3.UP)])
  arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
  arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
  var q=ArrayMesh.new();q.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var material=ShaderMaterial.new();material.shader=load("res://shaders/reference_chainlink.gdshader");material.set_shader_parameter("panel_size",Vector2(length/count,height))
  var v=mesh(arch,"ChainLinkPanel",Vector3.ZERO,q,material)
  v.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  rod(arch,"FencePost",start,start+Vector3.UP*height,.045,steel)
 rod(arch,"FencePost",b,b+Vector3.UP*height,.045,steel)
 rod(arch,"FenceTopRail",a+Vector3.UP*height,b+Vector3.UP*height,.045,steel)
 rod(arch,"FenceLowerRail",a,b,.035,steel)
 var body=StaticBody3D.new();body.name="FenceCollision";arch.add_child(body,true);body.owner=map
 var c=CollisionShape3D.new();var shape=ConvexPolygonShape3D.new()
 shape.points=PackedVector3Array([a-across,a+across,b-across,b+across,a-across+Vector3.UP*height,a+across+Vector3.UP*height,b-across+Vector3.UP*height,b+across+Vector3.UP*height])
 c.shape=shape;body.add_child(c,true);c.owner=map
func v_angle(d: Vector3)->float:return atan2(-d.z,d.x)
func prop(type: String,name: String,pos: Vector3,size: float=1.,rotation: float=0.):
 var n=load("res://assets/props/"+type+".tscn").instantiate();n.name=name;props.add_child(n,true);n.owner=map
 var bounds=AABB();var first=true
 for part in n.find_children("*","MeshInstance3D",true,false):
  var b: AABB=n.global_transform.affine_inverse()*part.global_transform*part.get_aabb()
  if first:bounds=b;first=false
  else:bounds=bounds.merge(b)
 if type in ["wooden_crate","metal_barrier"]:
  n.scene_file_path=""
  for child in n.find_children("*","Node",true,false):
   child.owner=map;child.scene_file_path=""
  for part in n.find_children("*","MeshInstance3D",true,false):
   for surface in range(part.mesh.get_surface_count()):
    var original=part.get_active_material(surface)
    if original is StandardMaterial3D:
     var painted=ShaderMaterial.new();painted.shader=load("res://shaders/reference_prop_finish.gdshader")
     painted.set_shader_parameter("paint_texture",original.albedo_texture)
     painted.set_shader_parameter("rust_frame",1. if type=="metal_barrier" else 0.)
     part.set_surface_override_material(surface,painted)
 n.scale=Vector3.ONE*(size/max(bounds.size.y,.01));n.position=pos-Vector3(0,bounds.position.y*n.scale.y,0);n.rotation.y=rotation
 var body=StaticBody3D.new();body.name="SolidCollision";n.add_child(body,true);body.owner=map
 var c=CollisionShape3D.new();c.name="PropBounds";var shape=BoxShape3D.new();shape.size=bounds.size*.84;c.shape=shape;c.position=bounds.get_center();body.add_child(c,true);c.owner=map
 return n
func house(pos: Vector3,width: float,depth: float,height: float,index: int,yaw: float=0.):
 var first_component=homes.get_child_count();house_count+=1
 var palette=["a69c82","b2a182","918b75","b5a18a","8f927f"]
 var body=box(homes,"BarangayHouse",pos+Vector3(0,height*.5,0),Vector3(width,height,depth),paint(palette[index%5]),true)
 var roofmat=roof_paint("969782",1 if absf(sin(yaw))>.5 else 0)
 for side in [-1,1]:
  var slope=box(homes,"CorrugatedRoof",pos+Vector3(side*width*.25,height+.35,0),Vector3(width*.55,.09,depth+.5),roofmat)
  slope.rotation.z=-side*.18
 for x in [-width*.27,width*.27]:
  box(homes,"DarkWindow",pos+Vector3(x,height*.57,depth*.501),Vector3(width*.21,.8,.04),dark)
  for j in range(3):box(homes,"WindowLouvre",pos+Vector3(x,height*.57-.27+j*.27,depth*.51),Vector3(width*.22,.04,.045),cream)
 box(homes,"Door",pos+Vector3(0,.9,depth*.503),Vector3(.9,1.8,.04),paint("6e6558"))
 box(homes,"FrontAwning",pos+Vector3(0,2.65,depth*.5+.35),Vector3(width*.9,.09,.85),roofmat)
 for side in [-1,1]:box(homes,"SideWindow",pos+Vector3(side*width*.501,height*.55,0),Vector3(.04,.85,1.0),dark)
 for side in [-1,1]:
  var face_x=pos.x+side*width*.505
  for z_offset in [-depth*.27,depth*.27]:
   box(homes,"SideWindowFrame",Vector3(face_x,height*.55,pos.z+z_offset),Vector3(.035,.95,.95),cream)
   box(homes,"SideWindowOpening",Vector3(face_x+side*.025,height*.55,pos.z+z_offset),Vector3(.035,.74,.74),dark)
   for rail in range(3):box(homes,"SideWindowSlat",Vector3(face_x+side*.05,height*.55-.25+rail*.25,pos.z+z_offset),Vector3(.035,.04,.74),cream)
 var timber=paint("827562");var trim=paint("9c9178")
 box(homes,"HousePlinth",pos+Vector3(0,.13,0),Vector3(width+.05,.26,depth+.05),paint("8f897b"))
 for side in [-1,1]:
  box(homes,"FacadeCornerPost",pos+Vector3(side*(width*.5-.07),height*.5,depth*.5+.04),Vector3(.13,height,.09),trim)
  box(homes,"GableEaveTrim",pos+Vector3(0,height,side*(depth*.5+.035)),Vector3(width,.10,.08),trim)
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var normal=Vector3(0,0,side)
  for v in [Vector3(-width*.5,height,side*depth*.5),Vector3(width*.5,height,side*depth*.5),Vector3(0,height+.69,side*depth*.5)]:
   st.set_normal(normal);st.add_vertex(v)
  var gable=mesh(homes,"ClosedHouseGable",pos,st.commit(),paint(palette[index%5]))
  gable.material_override=paint(palette[index%5]).duplicate();gable.material_override.shader=load("res://shaders/reference_closed_concrete.gdshader")
 for x in [-width*.27,width*.27]:
  var window_y=height*.57
  box(homes,"TimberWindowSill",pos+Vector3(x,window_y-.47,depth*.5+.06),Vector3(width*.24,.09,.13),trim)
  for side in [-1,1]:
   box(homes,"OpenWoodenShutter",pos+Vector3(x+side*width*.14,window_y,depth*.5+.09),Vector3(width*.065,.88,.08),timber)
  for slat in range(5):box(homes,"DoorPlank",pos+Vector3(-.36+slat*.18,.91,depth*.5+.04),Vector3(.012,1.65,.035),trim)
 for i in range(1,4):
  var zz=-depth*.5+i*depth/4.
  for side in [-1,1]:
   rod(homes,"RoofSheetOverlap",pos+Vector3(side*width*.54,height+.015,zz),pos+Vector3(0,height+.70,zz),.009,trim)
 if height>4.6:
  box(homes,"FacadeFloorBelt",pos+Vector3(0,2.2,depth*.5+.025),Vector3(width,.08,.06),trim)
 var rotation=Basis(Vector3.UP,yaw)
 for i in range(first_component,homes.get_child_count()):
  var component=homes.get_child(i)
  component.transform=Transform3D(rotation,pos)*Transform3D(Basis.IDENTITY,-pos)*component.transform
func ramp(name: String,x: float,width: float,z0: float,h0: float,z1: float,h1: float):
 var a=Vector3(x-width*.5,h0,z0);var b=Vector3(x+width*.5,h0,z0);var c=Vector3(x+width*.5,h1,z1);var d=Vector3(x-width*.5,h1,z1)
 var shape=ConcavePolygonShape3D.new();shape.set_faces(PackedVector3Array([a,b,c,a,c,d]));shape.backface_collision=true
 var body=StaticBody3D.new();body.name=name;arch.add_child(body,true);body.owner=map
 var col=CollisionShape3D.new();col.shape=shape;body.add_child(col,true);col.owner=map
func batch_architecture():
 var batches={};var originals=[]
 for group_node in [arch,homes]:
  for visual in group_node.find_children("*","MeshInstance3D",true,false):
   if not visual.mesh:continue
   var mat=visual.material_override
   if not mat is ShaderMaterial:continue
   if not mat.shader.resource_path in ["res://shaders/reference_paint.gdshader","res://shaders/reference_bunting.gdshader"]:continue
   var id=str(mat.get_instance_id())+":"+str(visual.cast_shadow)
   if not batches.has(id):batches[id]={"tool":SurfaceTool.new(),"mat":mat,"count":0,"shadow":visual.cast_shadow}
   var entry=batches[id]
   if entry.count==0:entry.tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   entry.tool.append_from(visual.mesh,0,map.global_transform.affine_inverse()*visual.global_transform)
   entry.count+=1;originals.append(visual)
 var render_group=group("StaticArchitectureBatches")
 for entry in batches.values():
  var geometry=entry.tool.commit()
  mesh(render_group,"PaintedArchitectureBatch",Vector3.ZERO,geometry,entry.mat).cast_shadow=entry.shadow
 for visual in originals:visual.visible=false
 print("BATCHED ",originals.size()," static meshes into ",batches.size()," material batches")
func closed_surface(parent: Node3D,name: String,vertices: PackedVector3Array,faces: Array,material: Material,solid: bool=true)->Node3D:
 var center=Vector3.ZERO
 for point in vertices:center+=point
 center/=vertices.size()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var collision_faces=PackedVector3Array()
 for face in faces:
  var a: Vector3=vertices[face[0]];var b: Vector3=vertices[face[1]];var c: Vector3=vertices[face[2]]
  var normal=(b-a).cross(c-a).normalized()
  if normal.dot((a+b+c)/3.-center)<0.:normal=-normal
  var order=[face[0],face[1],face[2]]
  if (b-a).cross(c-a).dot(normal)>0.:order=[face[0],face[2],face[1]]
  for index in order:
   tool.set_normal(normal);tool.add_vertex(vertices[index]);collision_faces.append(vertices[index])
 var geometry=tool.commit()
 var body=StaticBody3D.new() if solid else Node3D.new();body.name=name;parent.add_child(body,true);body.owner=map
 mesh(body,"ClosedPaintedSurface",Vector3.ZERO,geometry,material)
 if solid:
  var collision=CollisionShape3D.new();var shape=ConcavePolygonShape3D.new();shape.set_faces(collision_faces);shape.backface_collision=true
  collision.shape=shape;body.add_child(collision,true);collision.owner=map
 return body
func wedge(parent: Node3D,name: String,x: float,width: float,z0: float,h0: float,z1: float,h1: float,bottom: float,material: Material):
 var v=PackedVector3Array([Vector3(x-width/2,bottom,z0),Vector3(x+width/2,bottom,z0),Vector3(x+width/2,h0,z0),Vector3(x-width/2,h0,z0),Vector3(x-width/2,bottom,z1),Vector3(x+width/2,bottom,z1),Vector3(x+width/2,h1,z1),Vector3(x-width/2,h1,z1)])
 var faces=[[0,1,2],[0,2,3],[4,7,6],[4,6,5],[0,4,5],[0,5,1],[3,2,6],[3,6,7],[0,3,7],[0,7,4],[1,5,6],[1,6,2]]
 var m=material.duplicate();m.shader=load("res://shaders/reference_closed_concrete.gdshader")
 return closed_surface(parent,name,v,faces,m,true)
func rounded_path(xmin: float,xmax: float,zmin: float,zmax: float,radius: float)->PackedVector3Array:
 var points=PackedVector3Array()
 var corners=[Vector2(xmax-radius,zmax-radius),Vector2(xmin+radius,zmax-radius),Vector2(xmin+radius,zmin+radius),Vector2(xmax-radius,zmin+radius)]
 for corner in range(4):
  for segment in range(9):
   var angle=(corner*PI/2.)+segment*PI/16.
   points.append(Vector3(corners[corner].x+cos(angle)*radius,.2,corners[corner].y+sin(angle)*radius))
 return points
func sidewalk_ring():
 var outside=rounded_path(-27.2,27.2,-19.2,18.1,.9)
 var inside=rounded_path(-25.2,25.2,-17.2,16.9,.15)
 var vertices=PackedVector3Array();vertices.append_array(outside);vertices.append_array(inside)
 for p in outside:vertices.append(Vector3(p.x,0.,p.z))
 for p in inside:vertices.append(Vector3(p.x,0.,p.z))
 var n=outside.size();var faces=[]
 for i in range(n):
  var j=(i+1)%n
  faces.append_array([[i,j,n+j],[i,n+j,n+i],[i,2*n+j,j],[i,2*n+i,2*n+j],[n+i,n+j,3*n+j],[n+i,3*n+j,3*n+i],[2*n+i,3*n+j,2*n+j],[2*n+i,3*n+i,3*n+j]])
 var m=cream.duplicate();m.shader=load("res://shaders/reference_closed_concrete.gdshader")
 closed_surface(homes,"ContinuousRoundedSidewalk",vertices,faces,m,true)
 for points in [outside]:
  for i in range(n):
   var j=(i+1)%n;rod(homes,"ContinuousCurbEdge",points[i]+Vector3.UP*.01,points[j]+Vector3.UP*.01,.018,dark)
 # Paving seams run across the narrow ring, including the rear path.
 for x in range(-24,25,2):
  for zspan in [[16.9,18.1],[-19.2,-17.2]]:rod(homes,"SidewalkJoint",Vector3(x,.208,zspan[0]),Vector3(x,.208,zspan[1]),.008,paint("918b7b"))
 for z in range(-16,17,2):
  for side in [-1,1]:rod(homes,"SidewalkJoint",Vector3(side*25.2,.208,z),Vector3(side*27.2,.208,z),.008,paint("918b7b"))
func flag_paint(hex: String)->ShaderMaterial:
 var key="flag_"+hex
 if paint_cache.has(key):return paint_cache[key]
 var material=ShaderMaterial.new();material.shader=load("res://shaders/reference_bunting.gdshader");material.set_shader_parameter("flag_color",Color(hex));paint_cache[key]=material
 return material
func perimeter_utilities():
 # Four corner anchors, regular side/rear spacing; front center stays open.
 var anchors=[Vector3(-29.6,0.,-20.4),Vector3(-14.8,0.,-20.4),Vector3(0.,0.,-20.4),Vector3(14.8,0.,-20.4),Vector3(29.6,0.,-20.4),Vector3(29.6,0.,-7.95),Vector3(29.6,0.,4.5),Vector3(29.6,0.,16.95),Vector3(29.6,0.,29.4),Vector3(14.8,0.,29.4),Vector3(-14.8,0.,29.4),Vector3(-29.6,0.,29.4),Vector3(-29.6,0.,16.95),Vector3(-29.6,0.,4.5),Vector3(-29.6,0.,-7.95)]
 var colors=["a48367","b39b6d","84908b","91848f"]
 for anchor in anchors:
  rod(homes,"PerimeterUtilityPole",anchor,anchor+Vector3.UP*6.8,.085,paint("746b59"))
  box(homes,"PoleConcreteFoot",anchor+Vector3.UP*.25,Vector3(.25,.5,.25),cream)
  invisible_block(homes,"PerimeterPoleCollision",anchor+Vector3.UP*3.4,Vector3(.2,6.8,.2))
 for span in range(anchors.size()):
  var a=anchors[span]+Vector3.UP*6.65;var b=anchors[(span+1)%anchors.size()]+Vector3.UP*6.65
  for strand in range(2):
   var points=[]
   for i in range(17):
    var t=i/16.;var point=a.lerp(b,t);point.y+=strand*.12-.45*sin(t*PI);points.append(point)
   line(homes,"PerimeterSaggingCable",points,.018,dark)
  # Bunting stays on the rear and sides, away from the foreground camera.
  if a.z>28. and b.z>28.:continue
  var count=int(a.distance_to(b)/1.1)
  for i in range(count):
   var t=(i+.5)/count;var point=a.lerp(b,t);point.y-=.20+.45*sin(t*PI)
   var direction=(b-a).normalized();var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
   var normal=direction.cross(Vector3.UP)
   for v in [-direction*.16,direction*.16,Vector3(0,-.25,0)]:st.set_normal(normal);st.add_vertex(v)
   mesh(homes,"PerimeterFiestaFlag",point,st.commit(),flag_paint(colors[i%4]))
 map.set_meta("perimeter_pole_count",anchors.size())
func stage_wood()->ShaderMaterial:
 var material=ShaderMaterial.new();material.shader=load("res://shaders/reference_stage_timber.gdshader")
 material.set_shader_parameter("paint_texture",load("res://assets/environment/stage_wood.png"))
 return material
func profile_triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,normal: Vector3):
 if (b-a).cross(c-a).dot(normal)>0.:
  var swap=b;b=c;c=swap
 for v in [a,b,c]:tool.set_normal(normal);tool.add_vertex(v)
func profile_solid(parent: Node3D,name: String,x: float,width: float,outline: PackedVector2Array,material: Material,solid: bool=true)->Node3D:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var triangles=Geometry2D.triangulate_polygon(outline)
 assert(triangles.size()>0,"Invalid concrete profile")
 for side in [-1,1]:
  for i in range(0,triangles.size(),3):
   var a=outline[triangles[i]];var b=outline[triangles[i+1]];var c=outline[triangles[i+2]]
   profile_triangle(tool,Vector3(x+side*width/2,a.y,a.x),Vector3(x+side*width/2,b.y,b.x),Vector3(x+side*width/2,c.y,c.x),Vector3(side,0,0))
 var orientation=-1. if Geometry2D.is_polygon_clockwise(outline) else 1.
 for i in range(outline.size()):
  var a=outline[i];var b=outline[(i+1)%outline.size()];var d=b-a
  var normal=Vector3(0,d.x,-d.y).normalized()*orientation
  var v0=Vector3(x-width/2,a.y,a.x);var v1=Vector3(x+width/2,a.y,a.x)
  var v2=Vector3(x+width/2,b.y,b.x);var v3=Vector3(x-width/2,b.y,b.x)
  profile_triangle(tool,v0,v1,v2,normal);profile_triangle(tool,v0,v2,v3,normal)
 var geometry=tool.commit();var node=StaticBody3D.new() if solid else Node3D.new()
 node.name=name;parent.add_child(node,true);node.owner=map
 var finish=material.duplicate();finish.shader=load("res://shaders/reference_closed_concrete.gdshader")
 mesh(node,"ContinuousConcreteSurface",Vector3.ZERO,geometry,finish).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 if solid:
  var col=CollisionShape3D.new();var shape=ConcavePolygonShape3D.new();shape.set_faces(geometry.get_faces());shape.backface_collision=true;col.shape=shape;node.add_child(col,true);col.owner=map
 return node
func stair_profile(front: float,back: float,base: float,levels: Array,boundaries: Array)->PackedVector2Array:
 var outline=PackedVector2Array([Vector2(front,base),Vector2(back,base),Vector2(back,levels[-1])])
 for i in range(levels.size()-1,-1,-1):
  var z=boundaries[i]
  outline.append(Vector2(z,levels[i]))
  if i>0:outline.append(Vector2(z,levels[i-1]))
 return outline
func invisible_block(parent: Node3D,name: String,position: Vector3,size: Vector3):
 var body=StaticBody3D.new();body.name=name;body.position=position;parent.add_child(body,true);body.owner=map
 var col=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;col.shape=shape;body.add_child(col,true);col.owner=map
func road_barrier(x: float,z: float,yaw: float=PI/2.,base_height: float=.02):
 # Wide footing, sloped shoulders, narrow upright concrete wall.
 var outline=PackedVector2Array([Vector2(-.37,0),Vector2(.37,0),Vector2(.37,.23),Vector2(.17,.48),Vector2(.14,1.14),Vector2(-.14,1.14),Vector2(-.17,.48),Vector2(-.37,.23)])
 var body=profile_solid(homes,"RoadsideConcreteBarrier",0.,2.45,outline,cream,true)
 body.rotation.y=yaw;body.position=Vector3(x,base_height,z)
func apply_saved_block_adjustments():
 var path="res://assets/environment/moved_concrete_blocks.json"
 if not FileAccess.file_exists(path):return
 var entries=JSON.parse_string(FileAccess.get_file_as_string(path))
 var parent=map.get_node("StreetDetails/RoadsideConcreteBarrier6")
 for i in range(entries.size()):
  var entry=entries[i];var visual=map.get_node_or_null(entry.mesh_path)
  if visual==null and i==1:
   visual=map.get_node("StreetDetails/RoadsideConcreteBarrier/ContinuousConcreteSurface")
   visual.reparent(parent,false);visual.name="ContinuousConcreteSurface2";visual.owner=map
  visual.transform=str_to_var(entry.transform)
  var col=parent.get_node_or_null("CollisionShape3D" if i==0 else "MovedBlockCollision2")
  if col==null:
   col=CollisionShape3D.new();col.name="MovedBlockCollision2";parent.add_child(col);col.owner=map
  var faces=visual.mesh.get_faces()
  for v in range(faces.size()):faces[v]=visual.transform*faces[v]
  var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);shape.backface_collision=true
  col.shape=shape;col.transform=Transform3D.IDENTITY;col.disabled=false
 map.get_node("StreetDetails/RoadsideConcreteBarrier/CollisionShape3D").disabled=true
func build():
 reference_layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/reference_layout.json"))
 var roof_image=Image.load_from_file("res://assets/environment/reference_roof_paint.png");roof_image.generate_mipmaps()
 roof_texture=ImageTexture.create_from_image(roof_image)
 assert(ResourceSaver.save(roof_texture,"res://assets/environment/reference_roof_paint.res")==OK)
 roof_texture=load("res://assets/environment/reference_roof_paint.res")
 rng.seed=26016;map=Node3D.new();map.name="BarangayCourt";root.add_child(map,true)
 arch=group("Architecture");props=group("CourtProps");homes=group("StreetDetails")
 cream=paint("b8b4a0");orange=paint("b58755");steel=paint("787c73");dark=paint("4a4840");white=paint("e4dfc7")
 var floor=group("CourtFloor")
 box(floor,"StreetFoundation",Vector3(0,-.20,5),Vector3(84,.4,76),paint("77746b"),true)
 box(floor,"RaisedCourtPlatform",Vector3(0,.75,-1.5),Vector3(50,1.5,31),cream,true)
 box(floor,"OrangeBasketballCourt",Vector3(0,1.512,1.4),Vector3(43,.014,18.8),paint("a4835a"))
 # Fine paving joints around the painted court.
 for x in range(-24,25,2):
  for zrange in [[-17.,-8.1],[10.9,14.]]:rod(arch,"PavingJoint",Vector3(x,1.517,zrange[0]),Vector3(x,1.517,zrange[1]),.008,paint("918b7b"))
 for z in [-16,-14,-12,-10,12]:rod(arch,"PavingJoint",Vector3(-25,1.517,z),Vector3(25,1.517,z),.008,paint("918b7b"))
 var y=1.532
 line(arch,"CourtBoundary",[Vector3(-21.5,y,-8),Vector3(21.5,y,-8),Vector3(21.5,y,10.8),Vector3(-21.5,y,10.8),Vector3(-21.5,y,-8)],.095,white)
 line(arch,"HalfCourt",[Vector3(-.28,y,-8),Vector3(-.28,y,10.8)],.10,white)
 var circle=[]
 for i in range(65):circle.append(Vector3(cos(i*TAU/64)*2.-.28,y,1.4+sin(i*TAU/64)*2.))
 line(arch,"CenterCircle",circle,.09,white)
 for side in [-1,1]:
  var endx=side*21.5;var freex=side*15.8
  line(arch,"BasketballKey",[Vector3(endx,y,-1.4),Vector3(freex,y,-1.4),Vector3(freex,y,4.2),Vector3(endx,y,4.2)],.10,white)
  var arc=[]
  for i in range(49):
   var a=-PI/2+i*PI/48;arc.append(Vector3(endx-side*cos(a)*9.2,y,1.4+sin(a)*8.0))
  line(arch,"ThreePointArc",arc,.10,white)
  var free=[]
  for i in range(33):
   var a=-PI/2+i*PI/32;free.append(Vector3(freex-side*cos(a)*2.8,y,1.4+sin(a)*2.8))
  line(arch,"FreeThrowArc",free,.09,white)
  for i in range(12):
   var a=PI/2+i*PI/12
   rod(arch,"DashedFreeThrow",Vector3(freex-side*cos(a)*2.8,y,1.4+sin(a)*2.8),Vector3(freex-side*cos(a+.11)*2.8,y,1.4+sin(a+.11)*2.8),.035,white)
  # Backboards, bent support, ring and hanging basketball net.
  var x=side*22.4
  box(arch,"HoopPole",Vector3(x,3.25,1.4),Vector3(.15,3.5,.15),steel,true)
  rod(arch,"HoopBentArm",Vector3(x,4.9,1.4),Vector3(side*21.1,5.15,1.4),.07,steel)
  box(arch,"Backboard",Vector3(side*21.,4.75,1.4),Vector3(.12,1.35,2.25),paint("c8c7b4"))
  for z in [.35,2.45]:box(arch,"BackboardBorder",Vector3(side*20.93,4.75,z),Vector3(.025,1.35,.035),dark)
  for h in [4.1,5.4]:box(arch,"BackboardBorder",Vector3(side*20.93,h,1.4),Vector3(.025,.035,2.1),dark)
  for target_z in [1.02,1.78]:box(arch,"BackboardTargetMark",Vector3(side*20.925,4.535,target_z),Vector3(.025,.57,.035),dark)
  for target_y in [4.25,4.82]:box(arch,"BackboardTargetMark",Vector3(side*20.925,target_y,1.4),Vector3(.025,.035,.76),dark)
  var ring=[]
  for i in range(25):ring.append(Vector3(side*20.5+cos(i*TAU/24)*.34,4.25,1.4+sin(i*TAU/24)*.34))
  line(arch,"HoopRing",ring,.045,paint("765838"))
  for i in range(8):
   var a=TAU*i/8;rod(arch,"HoopNet",Vector3(side*20.5+cos(a)*.32,4.25,1.4+sin(a)*.32),Vector3(side*20.5+cos(a+.3)*.19,3.8,1.4+sin(a+.3)*.19),.008,white)
 # Continuous perimeter. Concrete and fencing climb with the rear stands.
 for side in [-1,1]:
  var x=side*25.
  box(arch,"SideConcreteBase",Vector3(x,1.15,1.725),Vector3(.38,2.3,24.55),orange,true)
  wedge(arch,"RisingBleacherPerimeter",x,.38,-10.55,2.3,-16.8,4.5,0.,orange)
  box(arch,"RearSideConcreteBase",Vector3(x,2.25,-16.9),Vector3(.38,4.5,.2),orange,true)
  fence(Vector3(x,2.3,-10.55),Vector3(x,2.3,14),2.65)
  fence(Vector3(x,4.5,-16.8),Vector3(x,2.3,-10.55),2.65)
  fence(Vector3(x,4.5,-17),Vector3(x,4.5,-16.8),2.65)
 box(arch,"RearConcreteBase",Vector3(0,2.25,-17),Vector3(50.38,4.5,.38),orange,true)
 fence(Vector3(-25,4.5,-17),Vector3(25,4.5,-17),2.65)
 for span in [[-25.,-16.95],[-11.45,-3.0],[2.5,11.20],[16.70,25.]]:
  var outer_start=span[0]-.19 if span[0]==-25. else span[0]
  var outer_end=span[1]+.19 if span[1]==25. else span[1]
  var center=(outer_start+outer_end)*.5;var length=outer_end-outer_start
  box(arch,"FrontConcreteRetainingWall",Vector3(center,1.15,14),Vector3(length,2.3,.38),orange,true)
  fence(Vector3(span[0],2.3,14),Vector3(span[1],2.3,14),2.65)
 for x in entrance_centers:
  for i in range(8):
   var tread_top=1.5-i*(1.3/8.)
   box(arch,"FilledEntranceStep",Vector3(x,(tread_top+.2)*.5,14.2+i*.34),Vector3(5.5,tread_top-.2,.35),cream)
   rod(arch,"StairNosing",Vector3(x-2.75,tread_top+.012,14.03+i*.34),Vector3(x+2.75,tread_top+.012,14.03+i*.34),.012,dark)
  box(arch,"StairBottomLanding",Vector3(x,.1,16.85),Vector3(5.5,.2,.30),cream,true)
  for side in [-1,1]:
   wedge(arch,"FilledEntranceCheek",x+side*2.83,.18,14.,2.3,17.,.45,.0,orange)
   rod(arch,"StairCheekCap",Vector3(x+side*2.83,2.33,14),Vector3(x+side*2.83,.48,17),.055,cream)
 # Closed, continuous concrete stair profiles avoid stacked-box overlaps.
 var seat_levels=[];var seat_boundaries=[]
 for i in range(7):
  seat_levels.append(1.5+(i+1)*.37)
  seat_boundaries.append(-10.62-i*.85 if i<6 else -15.6)
 var aisle_levels=[];var aisle_boundaries=[]
 for i in range(14):
  aisle_levels.append(1.5+(i+1)*.185);aisle_boundaries.append(-10.55-i*(5.05/14.))
 for side in [-1,1]:
  var aisles=bleacher_aisles[side].duplicate();aisles.sort()
  var spans=[[side*14.-9.3,aisles[0]-.6],[aisles[0]+.6,aisles[1]-.6],[aisles[1]+.6,side*14.+9.3]]
  for span in spans:
   if span[1]-span[0]<.1:continue
   profile_solid(arch,"BleacherSeating",(span[0]+span[1])*.5,span[1]-span[0],stair_profile(-10.62,-16.81,1.5,seat_levels,seat_boundaries),cream,true)
   # Flush painted nosing only on visible tier edges, never across the rear path.
   for i in range(6):
    box(arch,"FlushBleacherNosing",Vector3((span[0]+span[1])*.5,seat_levels[i]+.001,seat_boundaries[i]-.025),Vector3(span[1]-span[0],.002,.035),paint("777366")).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for x in aisles:
   for i in range(14):
    box(arch,"FlushAisleNosing",Vector3(x,aisle_levels[i]+.002,aisle_boundaries[i]-.018),Vector3(1.16,.002,.065),paint("d1c9b5")).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   box(arch,"AisleRearLandingSurface",Vector3(x,3.94,-16.205),Vector3(1.2,.30,1.21),paint("a39f8f"))
   profile_solid(arch,"BleacherAisleStair",x,1.2,stair_profile(-10.55,-15.6,1.5,aisle_levels,aisle_boundaries),paint("a39f8f"),false)
  # Solid orange guards rise above the treads on every exposed end.
  for x in [side*4.6,side*23.4]:
   wedge(arch,"OrangeBleacherSafetyWall",x,.22,-10.55,2.6,-15.6,5.19,1.5,orange)
  box(arch,"OuterRearSafetyReturn",Vector3(side*23.4,3.345,-16.205),Vector3(.22,3.69,1.21),orange,true)
  for x in aisles:
   for edge in [-1,1]:
    var marker=box(arch,"StairEntryChevron",Vector3(x+edge*.105,1.523,-10.03),Vector3(.065,.006,.34),paint("d1c9b5"))
    marker.rotation.y=edge*PI/4.;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  invisible_block(arch,"BleacherRearLanding",Vector3(side*14.,3.94,-16.205),Vector3(18.6,.30,1.21))
 # A continuous upper route connects both stands behind the stage.
 box(arch,"BehindStageBridge",Vector3(0,3.945,-16.205),Vector3(9.4,.29,1.21),cream,true)
 for x in [-4.4,0.,4.4]:
  box(arch,"BehindStageBridgeSupport",Vector3(x,2.65,-16.205),Vector3(.22,2.3,.75),orange,true)
  rod(arch,"BridgeGuardPost",Vector3(x,4.09,-15.59),Vector3(x,4.98,-15.59),.035,steel)
 rod(arch,"BridgeGuardTopRail",Vector3(-4.72,4.98,-15.59),Vector3(4.72,4.98,-15.59),.035,steel)
 rod(arch,"BridgeGuardMidRail",Vector3(-4.72,4.64,-15.59),Vector3(4.72,4.64,-15.59),.025,steel)
 # Central covered barangay stage.
 var timber=stage_wood()
 box(arch,"StagePlatform",Vector3(0,1.85,-12.8),Vector3(8, .7,5.4),timber,true)
 box(arch,"StageFrontStep",Vector3(0,1.67,-9.85),Vector3(8.4,.34,.55),timber,true)
 box(arch,"StageBackWall",Vector3(0,3.45,-15.4),Vector3(8,2.5,.22),paint("aaa68e"),true)
 for side in [-1,1]:
  box(arch,"StageCanopyPost",Vector3(side*3.8,3.45,-10.4),Vector3(.20,3.2,.20),cream,true)
  box(arch,"StageRearPost",Vector3(side*3.8,3.45,-15.3),Vector3(.20,3.2,.20),cream,true)
 box(arch,"StageCanopy",Vector3(0,5.15,-12.625),Vector3(8.8,.14,5.85),roof_paint("a1a18b",1))
 box(arch,"StageFascia",Vector3(0,4.95,-9.65),Vector3(8.8,.3,.17),cream)
 # Solid narrow obstacle walls, in positions matching the illustration.
 for data in [[Vector3(-12.7,2.15,-5.5),Vector3(.26,1.3,3.)],[Vector3(11.8,2.15,-5.8),Vector3(.26,1.3,3.)],[Vector3(-13.2,2.15,6.6),Vector3(.26,1.3,3.5)],[Vector3(11.85,2.15,6.3),Vector3(.26,1.3,3.5)],[Vector3(-5.9,1.95,-8),Vector3(3.4,.9,.26)],[Vector3(6.3,1.95,-8),Vector3(3.4,.9,.26)],[Vector3(-6.8,1.95,7.1),Vector3(3.2,.9,.26)],[Vector3(6.75,1.95,7.05),Vector3(3.2,.9,.26)]]:
  box(arch,"ConcreteCourtObstacle",data[0],data[1],cream,true)
 var diag=box(arch,"DiagonalConcreteObstacle",Vector3(-3.5,1.95,-4),Vector3(2.3,.9,.25),cream,true);diag.rotation.y=-.55
 var diag2=box(arch,"DiagonalConcreteObstacle",Vector3(-4.3,1.95,3.5),Vector3(1.7,.9,.25),cream,true);diag2.rotation.y=.7
 # Volleyball net: square woven mesh suspended above the court, with bound edges.
 var net_x=-.28;var net_start=-5.1;var net_end=7.9
 var net_bottom=2.93;var net_top=3.93
 for z in [net_start,net_end]:
  rod(arch,"VolleyballNetPost",Vector3(net_x,1.5,z),Vector3(net_x,4.12,z),.055,steel)
 var netmesh=QuadMesh.new();netmesh.size=Vector2(13.,net_top-net_bottom)
 var netmat=ShaderMaterial.new();netmat.shader=load("res://shaders/reference_volleyball_net.gdshader")
 netmat.set_shader_parameter("panel_size",Vector2(13.,1.))
 var net=mesh(arch,"CenterCourtVolleyballNet",Vector3(net_x,(net_bottom+net_top)*.5,1.4),netmesh,netmat);net.rotation.y=PI/2
 net.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 box(arch,"VolleyballTopTape",Vector3(net_x,net_top,1.4),Vector3(.035,.075,13.),white)
 box(arch,"VolleyballBottomTape",Vector3(net_x,net_bottom,1.4),Vector3(.025,.045,13.),white)
 for z in [net_start+.08,net_end-.08]:
  box(arch,"VolleyballSideTape",Vector3(net_x,3.43,z),Vector3(.025,1.,.045),white)
  rod(arch,"VolleyballTieCord",Vector3(net_x,net_top,z),Vector3(net_x,4.02,net_start if z<1.4 else net_end),.012,white)
 # Reference image ground-contact pins keep asymmetric prop groupings in the correct places.
 for name in ["back_crate","back_small_crate","front_crate_a","front_crate_b","right_foreground_crate","left_boundary_crate"]:
  prop("wooden_crate",name,pin(name),.85)
 for name in ["back_tires","middle_tires_left","middle_tires_left_low","middle_tires_right","middle_tires_right_low","left_boundary_tires"]:
  prop("tire_stack",name,pin(name),.68 if "low" in name else 1.)
 for name in ["back_chair_a","back_chair_b","back_chair_c","front_chair_a","front_chair_b","right_chair_a","right_chair_b","right_chair_c"]:
  prop("blue_plastic_chair",name,pin(name),.95,rng.randf_range(-.3,.3))
 prop("metal_barrier","FrontCourtBarrier",pin("front_barrier"),1.)
 # Road, sidewalk, storm drains and pedestrian markings.
 sidewalk_ring()
 box(homes,"FrontSidewalkApron",Vector3(0,.1,15.55),Vector3(50.4,.2,2.7),cream,true)
 for side in [-1,1]:
  for z in [15.55,18.05,20.55,23.05,25.55]:road_barrier(side*27.2,z)
  # Close the full side-alley mouth while leaving the front pavement accessible.
  invisible_block(homes,"SideAlleyBoundary",Vector3(side*27.,4.,14.3),Vector3(4.2,8.,.45))
 var asphalt=ShaderMaterial.new();asphalt.shader=load("res://shaders/reference_asphalt.gdshader")
 asphalt.set_shader_parameter("fine_texture",load("res://assets/environment/concrete.png"))
 asphalt.set_shader_parameter("wear_texture",load("res://assets/environment/painted_concrete_tile.png"))
 box(homes,"Road",Vector3(0,.013,22),Vector3(58.,.02,8),asphalt)
 for z in [18.25,25.75]:box(homes,"RoadEdgeMarking",Vector3(0,.027,z),Vector3(53.,.006,.075),paint("c4c1b1")).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for x in range(-24,25,4):
  if absf(x+20.)<2. or absf(x-18.9)<2.:continue
  box(homes,"RoadDash",Vector3(x,.029,22),Vector3(1.35,.006,.10),paint("d7d2be")).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for crossing in [[-20.0,18.50],[18.9,18.50]]:
  for stripe in range(11):box(homes,"ZebraCrossing",Vector3(crossing[0],.031,crossing[1]+stripe*.7),Vector3(2.5,.006,.32),paint("d7d2be"))
 for x in [-24,-6,6,24]:
  box(homes,"StormDrain",Vector3(x,.215,17.5),Vector3(1.3,.025,.5),dark)
  for i in range(8):box(homes,"DrainSlot",Vector3(x-.52+i*.15,.232,17.5),Vector3(.035,.015,.4),steel)
 for name in ["yellow_tricycle_a","purple_tricycle_a","yellow_tricycle_b","purple_tricycle_b"]:
  var trike=prop("street_tricycle","PurpleStreetTricycle" if name.begins_with("purple") else "YellowStreetTricycle",pin(name,0.),1.65,0.)
  props.remove_child(trike);homes.add_child(trike,true);trike.owner=map
 for data in [[-23.,16.6],[-22.,16.8],[-20.5,16.8]]:prop("wooden_crate" if data[0]<-21 else "tire_stack","SidewalkStoredProps",Vector3(data[0],.2,data[1]),.9)
 # Open, low surroundings preserve the gameplay camera sightline.
 for side in [-1,1]:
  box(homes,"OpenGravelVerge",Vector3(side*32.,.018,1.),Vector3(8.,.025,57.),paint("8d8778"))
 box(homes,"RearOpenVerge",Vector3(0,.018,-23.),Vector3(72.,.025,8.),paint("8d8778"))
 box(homes,"FarRoadOpenVerge",Vector3(0,.018,32.),Vector3(72.,.025,7.),paint("8d8778"))
 box(homes,"OppositeRoadSidewalk",Vector3(0,.1,27.1),Vector3(54.,.2,2.2),cream,true)
 for x in range(-26,27,2):
  box(homes,"OppositePavingJoint",Vector3(x,.202,27.1),Vector3(.018,.004,2.18),paint("918b7b")).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for i in range(21):road_barrier(-25.5+i*2.55,27.8,0.,.2)
 # Solid boundaries replace the removed house collision without visible tall walls.
 for side in [-1,1]:invisible_block(homes,"OpenWorldSideBoundary",Vector3(side*29.,4.,4.7),Vector3(.3,8.,48.))
 invisible_block(homes,"FarRoadBoundary",Vector3(0,4.,28.9),Vector3(58.,8.,.3))
 invisible_block(homes,"RearWorldBoundary",Vector3(0,4.,-19.5),Vector3(58.,8.,.3))
 # Damp patches removed: dry court surroundings.
 ramp("OppositeSidewalkAccess",0,54,25.5,.2,24.4,0.)
 ramp("OppositeSidewalkLanding",0,54,26.4,.2,25.5,.2)
 ramp("StreetSidewalkRamp",0,54,19.3,0.,18.6,.2)
 ramp("SidewalkRampLanding",0,54,18.6,.2,17.8,.2)
 for x in entrance_centers:
  ramp("FrontStairSmoothAccess",x,5.5,17.0,.2,14.5,1.5)
  ramp("FrontStairLanding",x,5.5,14.5,1.5,13.8,1.5)
 for x in bleacher_aisles[-1]+bleacher_aisles[1]:ramp("BleacherAccessRamp",x,1.2,-8.9+bleacher_setback,1.5,-15.6,4.09)
 ramp("StageAccessRamp",0,7.7,-7.9,1.5,-9.5,2.2)
 ramp("StageLanding",0,7.7,-9.5,2.2,-10.3,2.2)
 var net_body=StaticBody3D.new();net_body.name="CenterNetCollision";arch.add_child(net_body,true);net_body.owner=map
 var net_collision=CollisionShape3D.new();var net_shape=BoxShape3D.new();net_shape.size=Vector3(.08,1.8,13);net_collision.shape=net_shape;net_collision.position=Vector3(-.28,2.4,1.4);net_body.add_child(net_collision,true);net_collision.owner=map
 # Runtime expects these groups; zones are absent from the supplied reference.
 group("BaseSites");group("JailZones")
 perimeter_utilities()
 apply_saved_block_adjustments()
 if ResourceLoader.exists("res://assets/decals/front_wall_decals.tscn"):
  var art=load("res://assets/decals/front_wall_decals.tscn").instantiate();map.add_child(art);art.owner=map
 if ResourceLoader.exists("res://scenes/neighborhood_backdrop.tscn"):
  var backdrop=load("res://scenes/neighborhood_backdrop.tscn").instantiate();map.add_child(backdrop);backdrop.owner=map
 batch_architecture()
 var parameters=reference_layout["parameters"]
 map.scale=Vector3(parameters.scale_x,1.,parameters.scale_z)
 map.set_meta("reference_camera",{"position":Vector3(parameters.camera_x,31.,27.),"target":Vector3(parameters.target_x,1.5,parameters.target_z),"fov":parameters.fov})
 map.set_meta("reference_house_count",house_count)
 map.set_meta("entrance_centers",entrance_centers)
 map.set_meta("bleacher_setback",bleacher_setback)
 map.set_meta("bleacher_aisles",bleacher_aisles[-1]+bleacher_aisles[1])
 for group_node in [props,homes]:
  for prop_node in group_node.get_children():
   if prop_node.has_node("SolidCollision"):prop_node.scale*=Vector3(1./map.scale.x,1.,1./map.scale.z)
 for frame in range(3):await RenderingServer.frame_post_draw
 var packed=PackedScene.new();assert(packed.pack(map)==OK)
 assert(ResourceSaver.save(packed,"res://scenes/barangay_court.tscn")==OK)
 print("REFERENCE MAP BUILT: ",house_count," houses; open road surroundings, low concrete barriers; calibrated court/camera; joined fences and stairs")
 map.free();await process_frame;quit()































