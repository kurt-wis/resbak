class_name NeneModel
extends RefCounted

## A lightweight copy of a hero's model for Nene's IYAK! decoy and SUMBONG KITA! fake rescuer
## (docs/RESBAK.md § 4 Nene). Same GLB, scale and toon material as HeroVisual, no collision,
## no animation tree: just an AnimationPlayer playing one clip. The outline material is the
## owner's own (shared), so the copy always carries Nene's outline exactly as the viewer sees it.
## Presentation only.

## Returns the model root (scaled to model_height, feet on y = 0) or null if the GLB won't load.
## Child "Model" holds the mesh; `play(model, clips)` starts the first clip that exists.
static func build(data: HeroData, outline: Material = null, cast_shadows := true) -> Node3D:
	var packed := load(data.glb) as PackedScene
	if packed == null:
		return null
	var root := Node3D.new()
	root.name = "NeneCopy"
	var model := packed.instantiate() as Node3D
	model.name = "Model"
	root.add_child(model)
	var bounds := AABB()
	var found := false
	var meshes: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		meshes.append(mi)
		var rel := Transform3D.IDENTITY # mi relative to model (the model is not in the tree yet)
		var n: Node = mi
		while n != null and n != model:
			if n is Node3D:
				rel = (n as Node3D).transform * rel
			n = n.get_parent()
		var box: AABB = rel * mi.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	if found and bounds.size.y > 0.01:
		var k: float = data.model_height / bounds.size.y
		model.scale = Vector3.ONE * k
		model.position.y = -bounds.position.y * k
	var toon := load("res://shaders/character_toon.gdshader") as Shader
	for mi in meshes:
		if not cast_shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for surface in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(surface)
			var mat := ShaderMaterial.new()
			mat.shader = toon
			if src is StandardMaterial3D:
				mat.set_shader_parameter("base_texture", (src as StandardMaterial3D).albedo_texture)
				mat.set_shader_parameter("base_color", (src as StandardMaterial3D).albedo_color)
			if outline:
				mat.next_pass = outline
			mi.set_surface_override_material(surface, mat)
	return root

static func animator(root: Node3D) -> AnimationPlayer:
	for node in root.find_children("*", "AnimationPlayer", true, false):
		return node as AnimationPlayer
	return null

## Plays the first clip of `clips` the model has (looping if `loop`); returns its name or "".
static func play(root: Node3D, clips: Array, loop := true) -> String:
	var ap := animator(root)
	if ap == null:
		return ""
	for c in clips:
		if ap.has_animation(c):
			ap.get_animation(c).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			ap.play(c)
			return c
	return ""

## Face a flat direction (the model looks down +Z at rotation 0, as HeroVisual does).
static func face(root: Node3D, dir: Vector3) -> void:
	if root and RB.flat(dir).length() > 0.01:
		root.rotation.y = atan2(dir.x, dir.z)
