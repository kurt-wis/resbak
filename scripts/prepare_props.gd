extends SceneTree

var catalog := {
 "BluePlasticChair": ["blue_monobloc_chair_1k", 1.0],
 "WoodenCrate": ["wooden_crate_300tri", 1.15],
 "TireStack": ["tire_stack_1500tri", 1.15],
 "MetalBarrier": ["crowd_barrier_1800tri", 1.0],
 "TarpaulinBundle": ["tarpaulin_bundle_600tri", 0.45],
 "StageSpeaker": ["barangay_speaker_900tri_clean", 0.85],
 "PottedPlant": ["potted_tropical_plant_800tri", 1.25],
 "StreetTricycle": ["filipino_tricycle_5000tri", 2.1]
}

func _initialize() -> void:
 call_deferred("prepare")

func prepare() -> void:
 DirAccess.make_dir_recursive_absolute("res://assets/props")
 var report := []
 for asset_name in catalog:
  var source: String = catalog[asset_name][0]
  var height: float = catalog[asset_name][1]
  var path := "res://imported_models/%s/%s.glb" % [source, source]
  var imported: Node3D = load(path).instantiate()
  root.add_child(imported)
  var meshes := imported.find_children("*", "MeshInstance3D", true, false)
  if imported is MeshInstance3D:
   meshes.push_front(imported)
  var bounds := AABB()
  var first := true
  for item in meshes:
   var mesh: MeshInstance3D = item
   var local_bounds: AABB = imported.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
   bounds = local_bounds if first else bounds.merge(local_bounds)
   first = false
  var scale_factor := height / maxf(bounds.size.y, 0.01)
  var clean := Node3D.new()
  clean.name = asset_name
  var mesh_index := 0
  var textured := 0
  for item in meshes:
   var mesh: MeshInstance3D = item
   var visual := MeshInstance3D.new()
   visual.name = asset_name + "Mesh" + str(mesh_index + 1)
   visual.mesh = mesh.mesh.duplicate()
   visual.mesh.resource_name = asset_name + "Geometry"
   visual.transform = imported.global_transform.affine_inverse() * mesh.global_transform
   visual.transform.origin -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
   visual.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), Vector3.ZERO) * visual.transform
   for surface in range(visual.mesh.get_surface_count()):
    var original := mesh.get_active_material(surface) as StandardMaterial3D
    if original:
     var material := original.duplicate() as StandardMaterial3D
     material.resource_name = asset_name + "PaintedMaterial"
     material.metallic = 0.0
     material.metallic_texture = null
     material.roughness = 1.0
     material.roughness_texture = null
     material.metallic_specular = 0.0
     material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
     material.normal_enabled = false
     material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
     material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
     material.next_pass = null
     if material.albedo_texture:
      textured += 1
     visual.mesh.surface_set_material(surface, material)
   var mesh_path := "res://assets/props/%s_geometry_%d.res" % [asset_name.to_snake_case(), mesh_index + 1]
   assert(ResourceSaver.save(visual.mesh, mesh_path) == OK)
   clean.add_child(visual)
   visual.owner = clean
   mesh_index += 1
  var packed := PackedScene.new()
  assert(packed.pack(clean) == OK)
  assert(ResourceSaver.save(packed, "res://assets/props/%s.tscn" % asset_name.to_snake_case()) == OK)
  report.append({"name":asset_name,"meshes":meshes.size(),"textured_surfaces":textured,"height":height,"width":bounds.size.x*scale_factor,"depth":bounds.size.z*scale_factor})
  clean.free()
  imported.free()
 var report_file := FileAccess.open("C:/Users/Kurtl/Documents/Codex/2026-10-13/files-mentioned-by-the-user-agawan/work/prop-report.json",FileAccess.WRITE)
 report_file.store_string(JSON.stringify(report,"  "))
 print("PREPARED PROPS: ",JSON.stringify(report))
 quit()
