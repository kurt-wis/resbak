extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var scene=load("res://scenes/court_playtest.tscn").instantiate();root.add_child(scene)
 await physics_frame;scene.set_physics_process(false)
 var court=scene.get_node("BarangayCourt");var settings=court.get_meta("reference_camera")
 scene.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;scene.camera.position=settings.position;scene.camera.look_at(settings.target);scene.camera.fov=settings.fov
 await process_frame
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/reference_layout.json"))
 var points=[Vector3(-21.5,1.532,-8),Vector3(21.5,1.532,-8),Vector3(21.5,1.532,10.8),Vector3(-21.5,1.532,10.8)]
 var sum_error=0.;var maximum=0.;var rows=[]
 for i in range(4):
  var target=Vector2(layout.corners[i].target[0],layout.corners[i].target[1])
  var actual=scene.camera.unproject_position(court.to_global(points[i]))
  var error=actual.distance_to(target);sum_error+=error*error;maximum=maxf(maximum,error)
  rows.append({"target":[target.x,target.y],"actual":[actual.x,actual.y],"error_pixels":error})
 assert(maximum<8.,"Court geometry must align to the measured reference corners")
 var rms=sqrt(sum_error/4.)
 assert(court.get_meta("reference_house_count")==39)
 assert(court.get_node("StreetDetails").find_children("ClosedHouseGable*","MeshInstance3D",true,false).size()==78)
 var roof=court.get_node("Architecture/StageCanopy").material_override.get_shader_parameter("roof_texture")
 assert(roof!=null and roof.get_image().has_mipmaps())
 var file=FileAccess.open("C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/outputs/reference-corner-check.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"viewport":[1280,720],"rms_corner_distance_pixels":rms,"maximum_corner_distance_pixels":maximum,"corners":rows},"  "))
 print("VISUAL ALIGNMENT VERIFIED: court corner RMS ",rms,"px, maximum ",maximum,"px; 39 oriented houses, 78 closed gables, filtered roof texture")
 scene.free();await process_frame;quit()

