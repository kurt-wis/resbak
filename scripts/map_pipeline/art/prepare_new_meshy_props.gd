extends SceneTree

const CATALOG := {
	"shade_tree": ["Twisted Canopy",1024],
	"banana_plant": ["Banana Tree",512],
	"palamig_cart": ["Rainbow Refreshment Cart",1024],
	"park_bench": ["Weathered Park Bench",512],
	"croton_plant": ["Autumn Croton",512]
}

func _initialize(): call_deferred("prepare")

func prepare():
	DirAccess.make_dir_recursive_absolute("res://assets/props/neighborhood")
	var report := []
	for key in CATALOG:
		var source: String = CATALOG[key][0]
		var imported: Node3D = load("res://imported_models/"+source+"/"+source+".glb").instantiate()
		root.add_child(imported)
		var meshes := imported.find_children("*","MeshInstance3D",true,false)
		var bounds := AABB()
		var first := true
		for mesh in meshes:
			var box: AABB = imported.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		assert(bounds.size.y>0.01)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var anchor := Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		var scale_factor := 1.0/bounds.size.y
		var normalizer := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_factor),-anchor*scale_factor)
		var material := StandardMaterial3D.new()
		material.resource_name = key+"_MattePaint"
		material.roughness = 1.0
		material.metallic = 0.0
		material.metallic_specular = 0.0
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var texture_size := Vector2i.ZERO
		var triangles := 0
		for mesh in meshes:
			for surface in range(mesh.mesh.get_surface_count()):
				var original: StandardMaterial3D = mesh.get_active_material(surface)
				if material.albedo_texture==null and original and original.albedo_texture:
					var image := original.albedo_texture.get_image()
					if image.is_compressed(): image.decompress()
					var max_side: int = CATALOG[key][1]
					var factor := minf(1.0,float(max_side)/maxi(image.get_width(),image.get_height()))
					image.resize(maxi(1,roundi(image.get_width()*factor)),maxi(1,roundi(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
					image.generate_mipmaps()
					var texture := ImageTexture.create_from_image(image)
					var texture_path: String = "res://assets/props/neighborhood/"+key+"_albedo.res"
					assert(ResourceSaver.save(texture,texture_path,ResourceSaver.FLAG_COMPRESS)==OK)
					material.albedo_texture = load(texture_path)
					texture_size = image.get_size()
				st.append_from(mesh.mesh,surface,normalizer*imported.global_transform.affine_inverse()*mesh.global_transform)
			triangles += mesh.mesh.get_faces().size()/3
		st.set_material(material)
		var baked := st.commit()
		baked.resource_name = key+"_SharedGeometry"
		var mesh_path: String = "res://assets/props/neighborhood/"+key+"_mesh.res"
		assert(ResourceSaver.save(baked,mesh_path,ResourceSaver.FLAG_COMPRESS)==OK)
		var prepared := Node3D.new()
		prepared.name = key.to_pascal_case()
		var instance := MeshInstance3D.new()
		instance.name = "Model"
		instance.mesh = load(mesh_path)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		prepared.add_child(instance)
		instance.owner = prepared
		prepared.set_meta("source_model",source)
		prepared.set_meta("triangle_count",triangles)
		prepared.set_meta("unit_height",1.0)
		var scene := PackedScene.new()
		assert(scene.pack(prepared)==OK)
		assert(ResourceSaver.save(scene,"res://assets/props/neighborhood/"+key+".tscn")==OK)
		report.append({"asset":key,"triangles":triangles,"texture":str(texture_size),"normalized_size":str(bounds.size*scale_factor)})
		prepared.free()
		imported.free()
	var report_file := FileAccess.open("res://assets/props/neighborhood/model_report.json",FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report,"  "))
	print("NEW MESHY ASSETS PREPARED: ",JSON.stringify(report))
	quit()

