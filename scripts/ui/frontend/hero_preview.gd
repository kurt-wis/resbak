class_name HeroPreview
extends SubViewportContainer

## A hero model on a sand pad in its own SubViewport (the old character_select.gd approach,
## lit and framed like the in-game camera). show_hero() swaps the model; the clip loops
## (BreakDance by default, falling back to Idle).

var viewport: SubViewport
var root3d: Node3D
var model: Node3D
var player: AnimationPlayer
var hero_id := ""
var clip := ""
var cam: Camera3D

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c9c3e6")
	env.environment.ambient_light_energy = 0.55
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_color = Color("ffe1b8")
	sun.light_energy = 1.1
	viewport.add_child(sun)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.8
	disc.height = 0.08
	pad.mesh = disc
	pad.position.y = -0.04
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d9b98a")
	pad.material_override = mat
	viewport.add_child(pad)
	root3d = Node3D.new()
	viewport.add_child(root3d)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.1
	cam.position = Vector3(0, 3.1, 2.7)
	viewport.add_child(cam)
	cam.look_at.call_deferred(Vector3(0, 0.85, 0)) ## needs to be in the tree

func show_hero(id: String, p_clip := "BreakDance") -> void:
	if id == hero_id and p_clip == clip and model:
		return
	hero_id = id
	clip = p_clip
	if model:
		model.queue_free()
		model = null
		player = null
	var data := HeroData.load_hero(id)
	if data == null or data.glb == "":
		return
	model = (load(data.glb) as PackedScene).instantiate() as Node3D
	root3d.add_child(model)
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	if found and bounds.size.y > 0.01:
		var factor: float = 1.8 / bounds.size.y
		model.scale = Vector3.ONE * factor
		model.position.y = -bounds.position.y * factor
	for node in model.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		var use := p_clip if ap.has_animation(p_clip) else "Idle"
		if ap.has_animation(use):
			ap.get_animation(use).loop_mode = Animation.LOOP_LINEAR
			ap.play(use)
		player = ap
		break
