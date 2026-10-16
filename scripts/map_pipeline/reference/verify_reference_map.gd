extends SceneTree
func _initialize():call_deferred("verify")
func walk(body: CharacterBody3D,start: Vector3,velocity: Vector3,ticks: int)->Vector3:
 var actual_scale=body.get_parent().get_node("BarangayCourt").scale
 body.position=start*actual_scale;body.velocity=Vector3.ZERO
 for i in range(ticks):
  await physics_frame
  body.velocity.x=velocity.x*actual_scale.x;body.velocity.z=velocity.z*actual_scale.z
  if body.is_on_floor():body.velocity.y=0.
  else:body.velocity.y-=20.*(1./60.)
  body.move_and_slide()
 return body.position/actual_scale
func verify():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 var court=scene.get_node("BarangayCourt")
 var body=scene.player
 for x in court.get_meta("entrance_centers"):
  var p: Vector3=await walk(body,Vector3(x,.25,18.7),Vector3(0,-5,-3),140)
  print("STAIR UP ",x,": ",p)
  assert(p.z<13.5 and p.y>1.4,"Entrance must climb to deck")
  p=await walk(body,Vector3(x,1.6,12.6),Vector3(0,-5,3),140)
  print("STAIR DOWN ",x,": ",p)
  assert(p.z>18.4 and p.y<.3,"Entrance must descend to street")
 var p: Vector3=await walk(body,Vector3(24.,1.6,0),Vector3(3,-5,0),90)
 assert(p.x<24.7,"Perimeter must block walking through wire fence")
 p=await walk(body,Vector3(-1.,1.6,0),Vector3(3,-5,0),70)
 assert(p.x<-.3,"Center net must be solid")
 for x in court.get_meta("bleacher_aisles"):
  p=await walk(body,Vector3(x,1.6,-8.5+court.get_meta("bleacher_setback",0.)),Vector3(0,-1,-2),180)
  print("BLEACHER ",x,": ",p)
  assert(p.y>3.5,"Bleacher aisles must be accessible")
 p=await walk(body,Vector3(0,1.6,-7.7),Vector3(0,-1,-2),160)
 print("STAGE: ",p)
 assert(p.y>2.1,"Stage must be accessible")
 print("REFERENCE PLAYTEST PASSED: all three entrances work both ways; perimeter fence and net block movement")
 scene.free();await process_frame;quit()





