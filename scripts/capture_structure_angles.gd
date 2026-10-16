extends SceneTree
func _initialize():call_deferred("capture")
func capture():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 for child in scene.get_children():
  if child is CanvasLayer:child.visible=false
 var camera_settings=scene.get_node("BarangayCourt").get_meta("reference_camera")
 var views=[
 ["overview",camera_settings.position,camera_settings.target,camera_settings.fov],
 ["front",Vector3(0,7,21),Vector3(0,1.5,4),80.],
 ["rear",Vector3(0,12,-23),Vector3(0,2,-7),80.],
 ["left",Vector3(-18.4,4.8,3),Vector3(-15,3.6,-9.5),75.],
 ["right",Vector3(18.4,4.8,3),Vector3(15,3.6,-9.5),75.],
 ["stairs-side",Vector3(-13.2,.65,13.4),Vector3(-10.2,.8,12.),75.],
 ["front-corner",Vector3(-18.6,3.5,14.5),Vector3(-16.7,2.1,10.7),75.],
 ["rear-sidewalk",Vector3(-17.8,2.5,-16.2),Vector3(4.,.2,-14.6),75.],
 ["bleacher-aisle",Vector3(-11.56,3.2,-4.8),Vector3(-11.56,3.,-9.6),65.],
 ["roadside",Vector3(-16.,2.3,18.1),Vector3(-18.5,.7,17.),70.],
 ["top",Vector3(0,48,0),Vector3.ZERO,55.]]
 for view in views:
  scene.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;scene.camera.fov=view[3]
  var correction=scene.get_node("BarangayCourt").scale/Vector3(.68,1.,.8)
  scene.camera.position=view[1] if view[0]=="overview" else view[1]*correction
  if view[0]=="top":scene.camera.rotation_degrees=Vector3(-90,0,0)
  else:scene.camera.look_at(view[2] if view[0]=="overview" else view[2]*correction)
  for frame in range(5):await process_frame
  await RenderingServer.frame_post_draw
  var path="C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/structure-"+view[0]+".png"
  root.get_texture().get_image().save_png(path)
  print("CAPTURED ",view[0])
 scene.free();await process_frame;quit()
