extends SceneTree
func _initialize():
 run.call_deferred()
func run():
 var t=TestCtx.new(self)
 var host=t.make_match([{"hero_id":"inday","team":0},{"hero_id":"nathan","team":1}])
 t.go_live(host)
 var h=host.heroes[0]
 TestCtx.put(h,-6,-5)
 TestCtx.put(host.heroes[1],5,5)
 t.inputs(host).aim_at(h,Vector3(5,0,-5))
 t.inputs(host).press(h,RB.BTN_SKILL2)
 t.steps(host,9)
 await t.physics_frames(5)
 var v=h.visual
 var m=v.elastic_arm
 print("active",v.hila_pose_active(),"meta",m.get_meta("target_error",-1),"skeleton",m.get_skeleton(),"target",v.hila_visual_target())
 var sk=v._skel
 print("SCALE",sk.global_transform)
 for tail in ["RightArm","RightForeArm","RightHand"]:
  var i=sk.find_bone(v._bone_by_tail(tail))
  print(tail,sk.get_bone_global_pose(i),"pose",sk.get_bone_pose(i))
 m._process_modification()
 print("aftermanual",m.get_meta("target_error",-1))
 if sk.has_method("force_update_all_bone_transforms"):sk.force_update_all_bone_transforms()
 print("afterupdate",(sk.global_transform*sk.get_bone_global_pose(m.hand).origin).distance_to(v.hila_visual_target()))
 quit()
