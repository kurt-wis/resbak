extends SceneTree
func _initialize():call_deferred("capture")
func capture():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 for child in scene.get_children():
  if child is CanvasLayer:child.visible=false
 var scale=scene.get_node("BarangayCourt").scale
 scene.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;scene.camera.fov=65.
 scene.camera.position=Vector3(-24.4,5.5,-9.4)*scale;scene.camera.look_at(Vector3(-23.4,3.8,-13.5)*scale)
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 var folder="C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/"
 root.get_texture().get_image().save_png(folder+"wall-corrected-lighting.png")
 var cache={};var regex=RegEx.new();regex.compile("render_mode[^;]*;")
 for visual in scene.find_children("*","MeshInstance3D",true,false):
  var source=visual.material_override
  if not source is ShaderMaterial:continue
  if not source.shader.resource_path in ["res://shaders/reference_paint.gdshader","res://shaders/reference_closed_concrete.gdshader"]:continue
  var id=source.get_instance_id()
  if not cache.has(id):
   var material=source.duplicate();var shader=Shader.new();shader.code=regex.sub(source.shader.code,"render_mode unshaded,cull_disabled;")
   material.shader=shader;cache[id]=material
  visual.material_override=cache[id]
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"wall-neutral-material-check.png")
 print("CAPTURED: corrected real lighting and neutral unlit material check")
 scene.free();await process_frame;quit()
