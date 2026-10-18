class_name Portraits
extends Node

## Hero face portraits for the HUD tracker, the profile card, the draft and the results
## (rendered from the real models, so they always match the game). The first request for a
## hero renders its face once in an off-screen SubViewport (Idle pose, toon shading, head and
## shoulders) and caches it as an ImageTexture; until then face() returns null and callers draw
## initials. Boot pre-renders all five. Headless runs (the gate) never render.
## Draw helpers: draw_face() clips a portrait to a circle on any CanvasItem.

const SIZE := 256
const HEAD_BONE := "mixamorig:Head"
## Pose for the portrait: Idle at 0.4 s, except heroes whose idle looks down (rest pose).
const POSE_CLIP := {"tutoy": ""}
## The neck-to-crown span times this fills the portrait height (room for chin and hair).
const FRAME_MARGIN := 1.55

static var _cache := {} ## hero_id -> Texture2D
static var _studio: Portraits
signal ready_face(hero_id: String)

var _queue: Array[String] = []
var _busy := false

## The cached face of a hero, or null (and a render is queued).
static func face(hero_id: String) -> Texture2D:
	if _cache.has(hero_id):
		return _cache[hero_id]
	request(hero_id)
	return null

static func request(hero_id: String) -> void:
	if _cache.has(hero_id) or DisplayServer.get_name() == "headless":
		return
	var s := studio()
	if s and not (hero_id in s._queue):
		s._queue.append(hero_id)

static func request_all() -> void:
	for id in HeroData.ORDER:
		request(id)

static func studio() -> Portraits:
	if _studio and is_instance_valid(_studio):
		return _studio
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_studio = Portraits.new()
	_studio.name = "PortraitStudio"
	_studio.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_studio)
	return _studio

func _process(_delta: float) -> void:
	if _busy or _queue.is_empty():
		return
	_render(_queue.pop_front())

func _render(hero_id: String) -> void:
	_busy = true
	var data := HeroData.load_hero(hero_id)
	if data == null or data.glb == "" or not ResourceLoader.exists(data.glb):
		_busy = false
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d8d0f0")
	env.environment.ambient_light_energy = 0.7
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	sun.light_color = Color("ffe8c8")
	sun.light_energy = 1.15
	vp.add_child(sun)
	var model := (load(data.glb) as PackedScene).instantiate() as Node3D
	vp.add_child(model)
	_normalise(model, data.model_height)
	_toon(model)
	var anim: AnimationPlayer = null
	for n in model.find_children("*", "AnimationPlayer", true, false):
		anim = n
		break
	var clip: String = POSE_CLIP.get(hero_id, "Idle")
	if anim and clip != "" and anim.has_animation(clip):
		anim.play(clip)
		anim.seek(0.4, true)
		anim.pause()
	await get_tree().process_frame
	# Frame each hero by its own head: from the neck (head bone) to the crown (top of the
	# model). The chibi kids' heads are much bigger than JM's or Inday's, so a fixed distance
	# crops their chins: fit the neck-to-crown span (plus a margin) in the camera's view.
	var top := data.model_height
	var neck := Vector3(0, top - 0.45, 0)
	var sk_list := model.find_children("*", "Skeleton3D", true, false)
	if not sk_list.is_empty():
		var sk := sk_list[0] as Skeleton3D
		var b := sk.find_bone(HEAD_BONE)
		if b >= 0:
			neck = sk.global_transform * sk.get_bone_global_pose(b).origin
	var span := maxf(top - neck.y, 0.25)
	var look := Vector3(neck.x, neck.y + span * 0.42, neck.z)
	var cam := Camera3D.new()
	cam.fov = 24.0
	vp.add_child(cam)
	var dist := (span * FRAME_MARGIN * 0.5) / tan(deg_to_rad(cam.fov * 0.5))
	cam.look_at_from_position(look + Vector3(0.12, 0.05, 1.0).normalized() * dist, look)
	cam.current = true
	for i in range(3):
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img and not img.is_empty():
		img.generate_mipmaps()
		_cache[hero_id] = ImageTexture.create_from_image(img)
		ready_face.emit(hero_id)
	vp.queue_free()
	_busy = false

static func _normalise(model: Node3D, height: float) -> void:
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = model.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	if found and bounds.size.y > 0.01:
		var k: float = height / bounds.size.y
		model.scale = Vector3.ONE * k
		model.position.y = -bounds.position.y * k

static func _toon(model: Node3D) -> void:
	var toon := load("res://shaders/character_toon.gdshader")
	var outline := ShaderMaterial.new()
	outline.shader = load("res://shaders/character_outline.gdshader")
	outline.set_shader_parameter("outline_pixels", (load(Tuning.PATH) as Tuning).character_outline_pixels)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(s)
			var m := ShaderMaterial.new()
			m.shader = toon
			if src is StandardMaterial3D:
				m.set_shader_parameter("base_texture", (src as StandardMaterial3D).albedo_texture)
				m.set_shader_parameter("base_color", (src as StandardMaterial3D).albedo_color)
			m.next_pass = outline
			mi.set_surface_override_material(s, m)

# ---- drawing ----------------------------------------------------------------------------
## A circle-clipped portrait at `centre` with radius `r` on `ci` (inside its _draw). Draws a
## coloured disc behind, the face (or initials until it renders) and a ring.
static func draw_face(ci: CanvasItem, hero_id: String, centre: Vector2, r: float, bg: Color, ring: Color, ring_w := 3.0, dim := 0.0, font: Font = null) -> void:
	ci.draw_circle(centre, r, bg)
	var tex := face(hero_id)
	if tex:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var tint := Color(1, 1, 1).lerp(Color(0.35, 0.35, 0.4), dim)
		for i in range(40):
			var a := TAU * i / 40.0
			var d := Vector2(cos(a), sin(a))
			pts.append(centre + d * r)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5)
			cols.append(tint)
		ci.draw_polygon(pts, cols, uvs, tex)
	else:
		var data := HeroData.load_hero(hero_id)
		var txt := data.display_name.substr(0, 2).to_upper() if data else "?"
		var f := font if font else ThemeDB.fallback_font
		var fs := int(r * 0.9)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(f, centre + Vector2(-w * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 1.0 - dim * 0.4))
	if ring_w > 0.0:
		ci.draw_arc(centre, r, 0.0, TAU, 48, ring, ring_w, true)
