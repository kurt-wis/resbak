extends SceneTree
func _initialize():call_deferred("capture")
func capture():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 for child in scene.get_children():
  if child is CanvasLayer:child.visible=false
 var scale=scene.get_node("BarangayCourt").scale
 var views=[
 ["inner-left-stair-fixed",Vector3(-5.3,5.8,-8.8),Vector3(-5.3,3.,-13.5)],
 ["inner-right-stair-fixed",Vector3(5.3,5.8,-8.8),Vector3(5.3,3.,-13.5)],
 ["volleyball-net-detail",Vector3(-10.,5.,7.),Vector3(-.28,3.2,1.4)],
 ["stage-bridge-fixed",Vector3(-10.,7.,-16.2),Vector3(2.,4.09,-16.2)]]
 for view in views:
  scene.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;scene.camera.fov=75.
  scene.camera.position=view[1]*scale;scene.camera.look_at(view[2]*scale)
  for frame in range(5):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/"+view[0]+".png")
  print("CAPTURED ",view[0])
 scene.free();await process_frame;quit()

