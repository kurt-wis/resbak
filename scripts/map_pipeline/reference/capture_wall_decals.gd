extends SceneTree
func _initialize():call_deferred("capture")
func capture():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 for child in scene.get_children():
  if child is CanvasLayer:child.visible=false
 var scale=scene.get_node("BarangayCourt").scale
 var views=[["wall-decals-front",Vector3(0,7.,35.),Vector3(0,1.15,14.),75.],
 ["wall-decals-left",Vector3(-21.07,2.3,20.2),Vector3(-21.07,1.18,14.),62.],
 ["wall-decals-middle",Vector3(-7.225,2.3,20.2),Vector3(-7.225,1.18,14.),62.],
 ["wall-decals-right",Vector3(20.945,2.3,20.2),Vector3(20.945,1.18,14.),62.]]
 for view in views:
  scene.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;scene.camera.fov=view[3]
  scene.camera.position=view[1]*scale;scene.camera.look_at(view[2]*scale)
  for frame in range(5):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/"+view[0]+".png")
  print("CAPTURED ",view[0])
 scene.free();await process_frame;quit()
