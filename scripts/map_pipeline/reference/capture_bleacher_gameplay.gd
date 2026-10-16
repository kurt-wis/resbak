extends "res://scripts/map_pipeline/reference/verify_reference_map.gd"
func verify():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 for child in scene.get_children():
  if child is CanvasLayer:child.visible=false
 var positions=[["gameplay-left-stairs",Vector3(-5.3,3.5,-12.7)],["gameplay-right-stairs",Vector3(5.3,3.5,-12.7)],["gameplay-bleacher-seating",Vector3(-11.,3.5,-12.7)],["gameplay-outer-guard",Vector3(-22.3,3.5,-12.7)]]
 for item in positions:
  await walk(scene.player,item[1],Vector3.ZERO,40)
  var target=scene.player.position+Vector3(0,.65,0)
  scene.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;scene.camera.size=8.5
  scene.camera.position=target+Vector3(0,11,7.5);scene.camera.look_at(target)
  for i in range(5):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/"+item[0]+".png")
  print("CAPTURED ",item[0])
 scene.free();await process_frame;quit()
