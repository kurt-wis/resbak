extends SceneTree
var roof: Node3D
var panel_material: ShaderMaterial
var beam_material: ShaderMaterial
func _initialize() -> void:
	call_deferred("build")
func mesh_node(name: String, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = position
	node.material_override = material
	roof.add_child(node)
	node.owner = roof
	return node
func beam(name: String, a: Vector3, b: Vector3, width: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width,width,a.distance_to(b))
	var node := mesh_node(name,mesh,(a+b)*0.5,beam_material)
	node.look_at_from_position((a+b)*0.5,b,Vector3.RIGHT if absf((b-a).normalized().y) > 0.99 else Vector3.UP)
func build() -> void:
	roof = Node3D.new()
	roof.name = "CourtRoof"
	root.add_child(roof)
	panel_material = ShaderMaterial.new()
	panel_material.resource_name = "WeatheredCorrugatedRoof"
	panel_material.shader = load("res://shaders/cutaway_roof.gdshader")
	panel_material.render_priority = 10
	panel_material.set_shader_parameter("roof_color",Color("8996a9"))
	panel_material.set_shader_parameter("corrugated",true)
	panel_material.set_shader_parameter("cutaway",true)
	panel_material.set_shader_parameter("cutaway_radius",0.72)
	panel_material.set_shader_parameter("focus_uv",Vector2(0.5,0.5))
	panel_material.set_shader_parameter("emissive",0.0)
	beam_material = panel_material.duplicate()
	beam_material.resource_name = "RoofSteelTrusses"
	beam_material.set_shader_parameter("corrugated",false)
	beam_material.set_shader_parameter("roof_color",Color("3b4559"))
	for side in [-1,1]:
		var vertices := PackedVector3Array([Vector3(side*20,5.3,-12),Vector3(0,7.6,-12),Vector3(0,7.6,11.2),Vector3(side*20,5.3,11.2)])
		var uv := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
		var indices := PackedInt32Array([0,1,2,0,2,3])
		var normal := (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		if normal.y < 0: normal = -normal
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal,normal,normal,normal])
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.resource_name = "RoofSlopeGeometry"
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node := mesh_node("WestRoofSlope" if side==-1 else "EastRoofSlope",mesh,Vector3.ZERO,panel_material)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam("Eave"+str(side),Vector3(side*20,5.25,-12),Vector3(side*20,5.25,11.2),.18)
	beam("RidgeCap",Vector3(0,7.63,-12),Vector3(0,7.63,11.2),.25)
	for index in range(6):
		var z := -11.5+index*4.4
		beam("TieBeam"+str(index),Vector3(-19.6,5.15,z),Vector3(19.6,5.15,z),.14)
		for side in [-1,1]:
			beam("Rafter"+str(side)+"_"+str(index),Vector3(side*19.7,5.2,z),Vector3(0,7.5,z),.13)
			for x in [side*5,side*10,side*15]:
				beam("Web"+str(x)+"_"+str(index),Vector3(x,5.15,z),Vector3(x-side*2.3,7.5-abs(x-side*2.3)*.115,z),.075)
	# Perimeter support extensions connect to the previously built columns.
	for side in [-1,1]:
		for z in [-11.6,-4.0,4.0,10.8]:
			beam("ColumnExtension"+str(side)+str(z),Vector3(side*19.5,2.9,z),Vector3(side*19.5,5.2,z),.34)
	# Visible warm fixtures and real lights inside the canopy.
	var glow := panel_material.duplicate() as ShaderMaterial
	glow.resource_name = "WarmCourtLamps"
	glow.set_shader_parameter("corrugated",false)
	glow.set_shader_parameter("roof_color",Color("ffdda4"))
	glow.set_shader_parameter("emissive",1.2)
	for x in [-11,11]:
		for z in [-6,5]:
			var fixture := BoxMesh.new()
			fixture.size = Vector3(1.2,.12,.22)
			mesh_node("CourtLamp"+str(x)+str(z),fixture,Vector3(x,4.6,z),glow)
			var lamp := SpotLight3D.new()
			lamp.name = "WarmLight"+str(x)+str(z)
			lamp.position = Vector3(x,4.45,z)
			lamp.rotation_degrees.x = -90
			lamp.light_color = Color("ffe3bd")
			lamp.light_energy = 0.65
			lamp.spot_range = 9
			lamp.spot_angle = 65
			lamp.shadow_enabled = false
			roof.add_child(lamp)
			lamp.owner = roof
	var packed := PackedScene.new()
	assert(packed.pack(roof)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/court_roof.tscn")==OK)
	print("Roof built: corrugated slopes, steel trusses, column extensions, four court lamps")
	quit()



