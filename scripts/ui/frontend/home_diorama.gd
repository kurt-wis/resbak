class_name HomeDiorama
extends Node3D

## The Home screen's living backdrop: a sari-sari store at golden hour, five heroes talking and
## gesturing around it, a tricycle and four bystanders passing, all on a seamless 48 s loop
## (docs/plans/2026-10-17-home-diorama.md). Presentation only: nothing here touches gameplay.
## Heroes are stepped (AnimationTree one-shots fired by method tracks on `Timeline`); bystanders
## and the tricycle are pure functions of the loop time. Every number is in HomeDioramaData.

signal turn_started(hero_id: String, line_id: int) ## a hero starts talking or laughing (audio chatter)
signal pass_started ## the tricycle enters the back road

const SCENE := "res://scenes/frontend/home_diorama.tscn"
const PROP_DIR := "res://assets/props/home/"
const SET_SHADER := "res://shaders/diorama_set.gdshader"
const HEROES := ["inday", "nene", "jm", "nathan", "tutoy"]
const HIPS_BONE := "mixamorig_Hips" ## the seat fit reads the pelvis out of the sit clip
const TOE_BONES := ["mixamorig_LeftToeBase", "mixamorig_RightToeBase"] ## no sole may sink into the floor
const SEAT_SAMPLES := 24 ## frames of the sit clip sampled for the lowest sole
const REF_FLAG := "--home-ref" ## dev only: overlay the reference image at 50 % to line the set up
const STEP_MAX := 0.1 ## a stalled frame never skips a cue
const SEEK_STEP := 1.0 / 30.0
const DUST_LIFETIME := 14.0
const DUST_SIZE := 0.06
const SPLAT_DROPS := 4

var data: HomeDioramaData
var manual := false ## true: the owner calls step() (QC tools, tests); false: _process drives it
var time := 0.0 ## loop time, 0 .. loop_length
var actors := {} ## hero id -> DioramaActor
var walkers := {} ## bystander id -> DioramaActor
var camera: Camera3D
var timeline: AnimationPlayer
var pass_vehicle: Node3D
var seat_fit := {} ## hero id -> {pelvis, seat_top, sole, scale}: measured, not hand-tuned
var ref_overlay: TextureRect ## only built for --home-ref
var _speaker := ""
var _speaker_line := -1
var _built := false
var _env_node: WorldEnvironment
var _sky_mat: ShaderMaterial
var audio_enabled := false ## Home turns this on before adding the node; QC tools and tests stay silent
var _pass_engine: AudioStreamPlayer3D
var _pass_horn: AudioStreamPlayer3D
var _pass_u_prev := -1.0

func _ready() -> void:
	build()

## Idempotent: builds the world from `data` (HomeDioramaData.load_data() when none is set).
func build(p_data: HomeDioramaData = null) -> void:
	if _built:
		return
	_built = true
	data = p_data if p_data else (data if data else HomeDioramaData.load_data())
	_build_environment()
	_build_lights()
	_build_camera()
	_build_ground()
	_build_backdrop()
	_build_set()
	_build_walls()
	_build_cast()
	_build_bystanders()
	_build_pass()
	_build_dust()
	_build_timeline()
	_build_ref_overlay()
	seek_to(0.0)

## Dev only: a 50 % reference image over the frame so the camera, the set and each prop can be lined
## up 1:1 with the target art. Built for `--home-ref` (any command line) and nothing else, so it can
## never reach a build.
## Dev only, behind --home-ref: the reference image at 50 % over the frame, so the camera and every
## prop can be lined up 1:1. The reference lives under source_art/ (Godot-ignored, never imported), so
## it is decoded straight off disk instead of being loaded as a resource.
func _build_ref_overlay() -> void:
	if not OS.get_cmdline_args().has(REF_FLAG) and not OS.get_cmdline_user_args().has(REF_FLAG):
		return
	if not FileAccess.file_exists(data.ref_overlay):
		push_warning("HomeDiorama: no reference at %s" % data.ref_overlay)
		return
	var img := Image.load_from_file(data.ref_overlay)
	if img == null or img.is_empty():
		push_warning("HomeDiorama: could not decode %s" % data.ref_overlay)
		return
	var layer := CanvasLayer.new()
	layer.name = "RefOverlay"
	layer.layer = 128
	add_child(layer)
	ref_overlay = TextureRect.new()
	ref_overlay.name = "RefImage"
	ref_overlay.texture = ImageTexture.create_from_image(img)
	ref_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ref_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	ref_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ref_overlay.modulate = Color(1, 1, 1, data.ref_overlay_alpha)
	ref_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ref_overlay)

# ---- world ----------------------------------------------------------------------------------
func _node(name_: String, parent: Node = self) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	parent.add_child(n)
	return n

func _build_environment() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/diorama_sky.gdshader")
	_sky_mat.set_shader_parameter("top_color", data.sky_top)
	_sky_mat.set_shader_parameter("mid_color", data.sky_mid)
	_sky_mat.set_shader_parameter("horizon_color", data.sky_horizon)
	_sky_mat.set_shader_parameter("glow_color", data.sky_glow)
	_sky_mat.set_shader_parameter("cloud_lit", data.sky_cloud_lit)
	_sky_mat.set_shader_parameter("cloud_shade", data.sky_cloud_shade)
	_sky_mat.set_shader_parameter("cloud_cover", data.sky_cloud_cover)
	# the sun's direction in the sky is the light's +Z axis (a light shines down its -Z)
	var sun_basis := Basis.from_euler(Vector3(deg_to_rad(data.sun_rotation.x), deg_to_rad(data.sun_rotation.y), deg_to_rad(data.sun_rotation.z)))
	_sky_mat.set_shader_parameter("sun_dir", sun_basis * Vector3(0, 0, 1))
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = data.ambient_color
	env.ambient_light_energy = data.ambient_energy
	env.fog_enabled = true
	env.fog_light_color = data.fog_color
	env.fog_density = data.fog_density
	env.fog_sky_affect = 0.0 # the sky has its own gradient; fog would wash it to flat peach
	env.adjustment_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = data.exposure
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.0
	_env_node = WorldEnvironment.new()
	_env_node.name = "Environment"
	_env_node.environment = env
	add_child(_env_node)

func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = data.sun_color
	sun.light_energy = data.sun_energy
	sun.rotation_degrees = data.sun_rotation
	sun.shadow_enabled = true
	sun.shadow_opacity = data.sun_shadow_opacity
	sun.directional_shadow_max_distance = data.sun_shadow_max
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = data.fill_color
	fill.light_energy = data.fill_energy
	fill.rotation_degrees = data.fill_rotation
	add_child(fill)
	var win := OmniLight3D.new()
	win.name = "WindowLight"
	win.light_color = data.window_light_color
	win.light_energy = data.window_light_energy
	win.omni_range = data.window_light_range
	win.position = data.window_light_pos
	add_child(win)
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	bulb.mesh = sphere
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = data.bulb_color
	bulb.material_override = bm
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.position = data.bulb_pos
	bulb.visible = data.bulb_visible
	add_child(bulb)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = data.cam_fov
	camera.near = 0.3
	camera.far = 120.0
	camera.current = true
	add_child(camera)
	if data.dof_enabled:
		# full-screen post quad: depth-of-field behind the heroes (Compatibility has no built-in DoF)
		var dof := MeshInstance3D.new()
		dof.name = "DepthBlur"
		var quad := QuadMesh.new()
		quad.size = Vector2(2, 2)
		dof.mesh = quad
		dof.extra_cull_margin = 16384.0
		dof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dm := ShaderMaterial.new()
		dm.shader = load("res://shaders/diorama_dof.gdshader")
		dm.render_priority = 127
		dm.set_shader_parameter("blur_start", data.dof_start)
		dm.set_shader_parameter("blur_end", data.dof_end)
		dm.set_shader_parameter("radius", data.dof_radius)
		dof.material_override = dm
		camera.add_child(dof)
	camera.position = data.cam_position
	camera.look_at(data.cam_target)

## A flat toon-shaded box, shadows on: the ground, dashes and tree blobs share it.
func _flat(mesh: Mesh, color: Color, grain := 0.12, patch := 0.12, sat := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = load(SET_SHADER)
	m.set_shader_parameter("use_texture", false)
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("saturation", sat)
	m.set_shader_parameter("grain_strength", grain)
	m.set_shader_parameter("patch_strength", patch)
	mi.material_override = m
	return mi

## A graded, tiled-texture box or quad (ground slabs, building fronts). `uv_scale` repeats the
## texture; the mipmapped, repeating sampler keeps it clean at the grazing angles of the low camera.
func _textured(mesh: Mesh, tex_path: String, uv_scale: Vector2, sat := 0.95, grain := 0.05, patch := 0.06) -> MeshInstance3D:
	var mi := _flat(mesh, Color.WHITE, grain, patch, sat)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("use_texture", true)
	m.set_shader_parameter("base_texture", load(tex_path))
	m.set_shader_parameter("uv_scale", uv_scale)
	return mi

## Re-skins a set piece with the graded diorama shader (palette remap, soft light, grain). The
## ink outline is optional and off for the big Meshy pieces, whose noisy meshes make jagged lines.
func _style_piece(root: Node, piece: Dictionary) -> void:
	var sh := load(SET_SHADER) as Shader
	var ink: ShaderMaterial = null
	if piece.get("outline", false):
		ink = ShaderMaterial.new()
		ink.shader = load(DioramaActor.OUTLINE)
		ink.set_shader_parameter("outline_pixels", DioramaActor.OUTLINE_PX)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(s)
			if src is not StandardMaterial3D:
				continue
			var sm := src as StandardMaterial3D
			if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var m := ShaderMaterial.new()
			m.shader = sh
			m.set_shader_parameter("base_texture", sm.albedo_texture)
			m.set_shader_parameter("use_texture", sm.albedo_texture != null)
			m.set_shader_parameter("base_color", sm.albedo_color)
			m.set_shader_parameter("remap_palette", piece.get("remap", false))
			m.set_shader_parameter("saturation", piece.get("sat", data.set_saturation))
			m.set_shader_parameter("grain_scale", piece.get("grain_scale", 5.0))
			m.set_shader_parameter("grime_strength", piece.get("grime", 0.10))
			m.set_shader_parameter("value_gain", piece.get("gain", 1.02))
			m.set_shader_parameter("tint", piece.get("tint_shader", Color(1.0, 0.97, 0.92)))
			if ink:
				m.next_pass = ink
			mi.set_surface_override_material(s, m)

func _build_ground() -> void:
	var g := _node("Ground")
	for slab in data.ground:
		var plane := PlaneMesh.new()
		plane.size = slab.size
		var mi: MeshInstance3D
		if slab.has("texture"):
			var sz: Vector2 = slab.size
			mi = _textured(plane, slab.texture, sz / float(slab.tile))
		else:
			mi = _flat(plane, slab.color)
		mi.name = slab.name
		mi.position = slab.pos
		g.add_child(mi)
	var x := -35.0
	var n := 0
	while x < 35.0:
		var dash := BoxMesh.new()
		dash.size = Vector3(data.road_dash_len, 0.012, 0.16)
		var mi := _flat(dash, data.road_dash_color)
		mi.name = "Dash%d" % n
		mi.position = Vector3(x + data.road_dash_len * 0.5, 0.012, data.road_dash_z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
		x += data.road_dash_len + data.road_dash_gap
		n += 1
	var z := -24.0
	while z < 1.0:
		var dash := BoxMesh.new()
		dash.size = Vector3(0.16, 0.012, data.road_dash_len)
		var mi := _flat(dash, data.road_dash_color)
		mi.name = "SideDash%d" % n
		mi.position = Vector3(data.side_road_dash_x, 0.012, z + data.road_dash_len * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
		z += data.road_dash_len + data.road_dash_gap
		n += 1
	# Paint splatter: a main blob plus uneven satellite droplets, dull and grainy like dried paint
	# on concrete (not the candy discs of the first pass).
	var i := 0
	for s in data.splats:
		var col: Color = (s.color as Color).lerp(data.ground[0].color, data.splat_fade)
		for k in range(SPLAT_DROPS + 1):
			var disc := CylinderMesh.new()
			var r := float(s.r) * (1.0 if k == 0 else 0.16 + 0.12 * fmod(k * 0.37 + i * 0.21, 1.0))
			disc.top_radius = r
			disc.bottom_radius = r
			disc.height = 0.004
			disc.radial_segments = 11
			var mi := _flat(disc, col, 0.35, 0.2, 0.8)
			mi.name = "Splat%d_%d" % [i, k]
			var ang := k * 2.399 + i * 1.3
			var off := Vector3.ZERO if k == 0 else Vector3(cos(ang), 0, sin(ang)) * float(s.r) * (1.25 + 0.5 * fmod(k * 0.61, 1.0))
			mi.position = s.pos + off + Vector3(0, 0.006 + 0.0004 * i + 0.00005 * k, 0)
			mi.scale = Vector3(1.0 + 0.45 * sin(i * 2.3 + k), 1.0, 1.0 + 0.45 * cos(i * 1.7 + k * 2.0))
			mi.rotation_degrees.y = i * 37.0 + k * 53.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(mi)
		i += 1

## The street wall behind the court (data.backdrop): a box body per building with a textured front
## quad (windows, shutters, stains) so the horizon is a town, not a peach void. Fog hazes it.
func _build_backdrop() -> void:
	var holder := _node("Backdrop")
	var i := 0
	for b in data.backdrop:
		var w: float = b.w
		var h: float = b.h
		var d: float = data.backdrop_depth
		var body := BoxMesh.new()
		body.size = Vector3(w, h, d)
		var bm := _flat(body, b.color, 0.1, 0.12, 0.9)
		bm.name = "Building%d" % i
		bm.position = Vector3(b.x, h * 0.5, data.backdrop_z - d * 0.5)
		holder.add_child(bm)
		var quad := QuadMesh.new()
		quad.size = Vector2(w, h)
		var front := _textured(quad, "res://assets/props/home/facade_%s.png" % b.tex, Vector2(maxf(1.0, roundf(w / 8.0)), maxf(2.0, roundf(h / 2.67)) / 3.0))
		front.name = "Front%d" % i
		front.position = Vector3(b.x, h * 0.5, data.backdrop_z + 0.02)
		front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(front)
		if b.get("tank", false):
			var tank := CylinderMesh.new()
			tank.top_radius = 0.85
			tank.bottom_radius = 0.85
			tank.height = 1.5
			var tm := _flat(tank, Color("5f7da0"), 0.1, 0.1, 0.7)
			tm.position = Vector3(b.x + w * 0.2, h + 1.25, data.backdrop_z - d * 0.5)
			tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(tm)
			var legs := BoxMesh.new()
			legs.size = Vector3(1.5, 0.5, 1.5)
			var lm := _flat(legs, Color("4a4540"), 0.1, 0.05, 0.6)
			lm.position = Vector3(b.x + w * 0.2, h + 0.25, data.backdrop_z - d * 0.5)
			lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(lm)
		i += 1

func _build_set() -> void:
	var s := _node("Set")
	var i := 0
	for piece in data.set_pieces:
		var path: String = piece.get("path", PROP_DIR + String(piece.scene) + ".tscn")
		var prop := (load(path) as PackedScene).instantiate() as Node3D
		prop.name = "%s%d" % [piece.scene, i]
		s.add_child(prop)
		prop.position = piece.pos
		prop.rotation_degrees.y = piece.get("yaw", 0.0)
		var sc: Variant = piece.get("scale", 1.0)
		prop.scale = sc if sc is Vector3 else Vector3.ONE * float(sc)
		if piece.get("toon", false):
			if piece.has("tint"):
				tint_root(prop, piece.tint)
			DioramaActor.toonify(prop, piece.get("outline", true))
		else:
			_style_piece(prop, piece)
		i += 1

## Multiply every opaque material's albedo by `color`: the plastic props are baked neutral grey in
## Blender so one stool model can be a red, blue or teal stool from data (HomeSkin-style tinting).
func tint_root(root: Node, color: Color) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(s)
			if src is not StandardMaterial3D:
				continue
			var sm := src as StandardMaterial3D
			var m := sm.duplicate() as StandardMaterial3D
			m.albedo_color = sm.albedo_color * color
			mi.set_surface_override_material(s, m)

func _build_walls() -> void:
	var holder := _node("Walls")
	for w in data.walls:
		var box := BoxMesh.new()
		box.size = w.size
		var mi := MeshInstance3D.new()
		mi.name = w.name
		mi.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(w.texture)
		m.roughness = 1.0
		m.uv1_scale = Vector3(1.0, 1.0, 1.0)
		mi.material_override = m
		mi.position = w.pos
		mi.rotation_degrees.y = w.yaw
		holder.add_child(mi)
	var i := 0
	for b in data.boxes:
		var bm := BoxMesh.new()
		bm.size = b.size
		var cb := _flat(bm, b.color, 0.22, 0.14, 0.7)
		cb.name = "Box%d" % i
		cb.position = b.pos
		cb.rotation_degrees.y = b.yaw
		holder.add_child(cb)
		# packing tape over the lid seam, and a darker flap crease, so it reads as a carton
		var sz: Vector3 = b.size
		var tape := BoxMesh.new()
		tape.size = Vector3(sz.x * 0.16, 0.006, sz.z * 1.02)
		var tp := _flat(tape, Color("d9c79a"), 0.1, 0.05, 0.6)
		tp.position = Vector3(0, sz.y * 0.5 + 0.003, 0)
		tp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cb.add_child(tp)
		var crease := BoxMesh.new()
		crease.size = Vector3(sz.x * 1.01, sz.y * 0.025, sz.z * 1.01)
		var cr := _flat(crease, (b.color as Color).darkened(0.35), 0.2, 0.05, 0.7)
		cr.position = Vector3(0, sz.y * 0.5 - sz.y * 0.18, 0)
		cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cb.add_child(cr)
		i += 1

## Sit each hero on its stool from measured geometry rather than hand-tuned offsets (the old build
## put every stool under the hero root with `stool_dy` 0, so the sitters floated or sank): the pelvis
## comes from the sit clip itself, the seat height from the stool's own mesh, and the stool is scaled
## so its seat top lands `seat_pad` under the pelvis. If the clip would push a sole through the floor,
## both the hero and the stool rise by that amount - the gap stays 0 on the ground.
func _build_cast() -> void:
	var holder := _node("Heroes")
	for hero_id in HEROES:
		var e: Dictionary = data.cast[hero_id]
		var actor := DioramaActor.new()
		actor.name = hero_id
		holder.add_child(actor)
		actor.position = e.pos + Vector3(0, float(e.get("hero_dy", 0.0)), 0)
		actor.rotation_degrees.y = e.yaw
		if not actor.build_hero(hero_id, data, e):
			push_warning("HomeDiorama: could not build %s" % hero_id)
			continue
		actors[hero_id] = actor
		if String(e.get("stool", "")) != "":
			_seat_actor(actor, hero_id, e)

## Sample the hero's base clip by hand: the AnimationTree owns the skeleton at runtime, so the
## AnimationPlayer has to be played and seeked explicitly to ask the skeleton what a frame looks like.
## The tree re-applies its own pose on its next advance, so hand-driving the player is safe here.
func _sample_base(actor: DioramaActor) -> Array:
	var samples: Array = []
	if actor == null or actor.animator == null or actor.skeleton == null or actor._clip == "":
		return samples
	var skel := actor.skeleton
	var hips := skel.find_bone(HIPS_BONE)
	if hips < 0:
		return samples
	var toes: Array[int] = []
	for n in TOE_BONES:
		var b := skel.find_bone(n)
		if b >= 0:
			toes.append(b)
	actor.animator.play(actor._clip)
	for i in SEAT_SAMPLES + 1:
		actor.animator.seek(actor._clip_len * float(i) / float(SEAT_SAMPLES), true)
		skel.force_update_all_bone_transforms()
		var sole := INF
		for b in toes:
			sole = minf(sole, (skel.global_transform * skel.get_bone_global_pose(b).origin).y)
		samples.append({"pelvis": skel.global_transform * skel.get_bone_global_pose(hips).origin, "sole": sole})
	actor.animator.stop()
	return samples

func _seat_actor(actor: DioramaActor, hero_id: String, e: Dictionary) -> void:
	var samples := _sample_base(actor)
	if samples.is_empty():
		return
	var pelvis: Vector3 = samples[0].pelvis
	var sole := INF
	for s in samples:
		sole = minf(sole, float(s.sole))
	var lift := maxf(0.0, -sole) if sole < INF else 0.0
	if lift > 0.0:
		actor.position.y += lift
		pelvis.y += lift
	var stool := (load(PROP_DIR + String(e.stool) + ".tscn") as PackedScene).instantiate() as Node3D
	stool.name = "Stool_" + hero_id
	get_node("Set").add_child(stool)
	var seat := _local_top(stool)
	if seat <= 0.01:
		return
	var s := maxf(0.05, (pelvis.y - data.seat_pad) / seat)
	if e.has("stool_tint"):
		tint_root(stool, e.stool_tint)
	DioramaActor.toonify(stool, true)
	stool.scale = Vector3.ONE * s
	stool.position = Vector3(pelvis.x, 0.0, pelvis.z)
	stool.rotation_degrees.y = e.yaw
	seat_fit[hero_id] = {"pelvis": pelvis.y, "seat_top": seat * s, "sole": sole, "scale": s}

## Highest point of a prop in its own local space - a stool's seat - before scaling.
func _local_top(root: Node3D) -> float:
	var top := 0.0
	var inv := root.global_transform.affine_inverse()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var a: AABB = mi.get_aabb()
		var xf: Transform3D = inv * mi.global_transform
		for c in 8:
			top = maxf(top, (xf * a.get_endpoint(c)).y)
	return top

## The sitter's pelvis and lowest toe *right now*, plus the seat fit the builder stored. The suite reads
## this at rest and all through the loop, so the seat fit is held to the tolerance by measurement on the
## pose the AnimationTree actually drives, not by trusting the builder's own numbers.
func sitter_pose(hero_id: String) -> Dictionary:
	var actor: DioramaActor = actors.get(hero_id)
	if actor == null or actor.skeleton == null or not seat_fit.has(hero_id):
		return {}
	var skel := actor.skeleton
	var hips := skel.find_bone(HIPS_BONE)
	if hips < 0:
		return {}
	var pelvis: Vector3 = skel.global_transform * skel.get_bone_global_pose(hips).origin
	var sole := INF
	for n in TOE_BONES:
		var b := skel.find_bone(n)
		if b >= 0:
			sole = minf(sole, (skel.global_transform * skel.get_bone_global_pose(b).origin).y)
	var fit: Dictionary = seat_fit[hero_id]
	return {"pelvis": pelvis.y, "pelvis_x": pelvis.x, "pelvis_z": pelvis.z, "sole": sole,
			"seat_top": float(fit.seat_top), "pad": data.seat_pad, "scale": float(fit.scale)}

func _build_bystanders() -> void:
	var holder := _node("Bystanders")
	for who in data.bystanders:
		var e: Dictionary = data.bystanders[who]
		var actor := DioramaActor.new()
		actor.name = who
		holder.add_child(actor)
		if actor.build_bystander(who, data, e):
			walkers[who] = actor
			if e.has("pos"):
				actor.position = e.pos
				actor.rotation_degrees.y = e.yaw
		else:
			push_warning("HomeDiorama: could not build bystander %s" % who)

func _build_pass() -> void:
	var holder := _node("Vehicles")
	pass_vehicle = (load(data.pass_scene) as PackedScene).instantiate() as Node3D
	pass_vehicle.name = "Tricycle"
	holder.add_child(pass_vehicle)
	pass_vehicle.scale = Vector3.ONE * data.pass_scale
	pass_vehicle.rotation_degrees.y = data.pass_yaw
	DioramaActor.toonify(pass_vehicle, true)
	pass_vehicle.visible = false
	if audio_enabled:
		_pass_engine = _pass_voice("home/jeep_pass")
		_pass_horn = _pass_voice("home/jeep_horn")

## The tricycle carries its own 3D voices, so the pass pans and fades with it (the Home viewport
## listens through the diorama camera).
func _pass_voice(sound: String) -> AudioStreamPlayer3D:
	var path := "res://assets/audio/%s.wav" % sound
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = sound.get_file().to_pascal_case()
	p.stream = load(path)
	p.bus = "Effects"
	p.max_distance = data.pass_audio_range
	p.unit_size = 8.0
	pass_vehicle.add_child(p)
	return p

func _build_dust() -> void:
	var fx := _node("FX")
	var p := CPUParticles3D.new()
	p.name = "Dust"
	p.amount = data.dust_amount
	p.lifetime = DUST_LIFETIME
	p.preprocess = DUST_LIFETIME
	p.randomness = 1.0
	p.fixed_fps = 30
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = data.dust_box
	p.direction = Vector3(0.3, 1.0, 0.2)
	p.spread = 25.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.08
	p.gravity = Vector3.ZERO
	p.position = data.dust_pos
	var quad := QuadMesh.new()
	quad.size = Vector2(DUST_SIZE, DUST_SIZE)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1.0, 0.86, 0.6, 0.35)
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.gradient = Gradient.new()
	soft.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	m.albedo_texture = soft
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(p)

# ---- timeline -------------------------------------------------------------------------------
func _build_timeline() -> void:
	timeline = AnimationPlayer.new()
	timeline.name = "Timeline"
	timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	timeline.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(timeline)
	timeline.root_node = timeline.get_path_to(self)
	var anim := Animation.new()
	anim.length = data.loop_length
	anim.loop_mode = Animation.LOOP_LINEAR
	# One method track per gesture: a track keeps a single key per instant, so two gestures that end
	# at the same time (Tutoy's and Nathan's both ended at 37.6 s) would silently drop one end cue
	# and leave that hero's gesture playing to the end of its clip.
	for i in range(data.gestures.size()):
		var g: Dictionary = data.gestures[i]
		var track := anim.add_track(Animation.TYPE_METHOD)
		anim.track_set_path(track, NodePath("."))
		anim.track_insert_key(track, g.t, {"method": "_cue_gesture", "args": [i]})
		anim.track_insert_key(track, minf(g.t + g.dur, data.loop_length - 0.01), {"method": "_cue_gesture_end", "args": [i]})
	var pass_track := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(pass_track, NodePath("."))
	anim.track_insert_key(pass_track, data.pass_t0, {"method": "_cue_pass", "args": []})
	var lib := AnimationLibrary.new()
	lib.add_animation("loop", anim)
	timeline.add_animation_library("", lib)
	timeline.play("loop")
	timeline.pause()

func _cue_gesture(i: int) -> void:
	var g: Dictionary = data.gestures[i]
	var a: DioramaActor = actors.get(g.hero)
	if a:
		a.request_gesture(g.clip, g.get("full", false))

func _cue_gesture_end(i: int) -> void:
	var g: Dictionary = data.gestures[i]
	var a: DioramaActor = actors.get(g.hero)
	if a:
		a.end_gesture(g.get("full", false))

func _cue_pass() -> void:
	pass_started.emit()

# ---- stepping -------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not manual:
		step(delta)

## Advances the whole diorama by `delta` seconds (clamped so cues are never skipped).
func step(delta: float) -> void:
	delta = minf(delta, STEP_MAX)
	timeline.advance(delta)
	time = timeline.current_animation_position
	_update_speech()
	for hero_id in actors:
		(actors[hero_id] as DioramaActor).step(delta, time)
	_update_bystanders()
	_update_pass()
	_sky_mat.set_shader_parameter("phase", fposmod(time, data.loop_length) / data.loop_length)

## Jump to loop time `t`: aborts every gesture, then replays the schedule from 0 at 30 Hz so a
## still taken at t shows exactly what a viewer sees t seconds into the loop.
func seek_to(t: float) -> void:
	for hero_id in actors:
		var a: DioramaActor = actors[hero_id]
		a.abort_gestures()
	_speaker = ""
	_speaker_line = -1
	timeline.seek(0.0, true)
	timeline.pause()
	time = 0.0
	var was_manual := manual
	manual = true
	var elapsed := 0.0
	while elapsed < t - 0.0001:
		var d := minf(SEEK_STEP, t - elapsed)
		step(d)
		elapsed += d
	if t <= 0.0001:
		step(0.0)
	manual = was_manual

func _update_speech() -> void:
	var mode := {}
	var speaker := ""
	var speaker_line := -1
	var latest := -1.0
	for i in range(data.speech.size()):
		var s: Dictionary = data.speech[i]
		if time < s.t0 or time >= s.t1:
			continue
		var m := FaceRig.Mode.SMILE
		match String(s.mode):
			HomeDioramaData.SPEECH_TALK:
				m = FaceRig.Mode.TALK
			HomeDioramaData.SPEECH_LAUGH:
				m = FaceRig.Mode.LAUGH
		var cur: int = mode.get(s.hero, FaceRig.Mode.CLOSED)
		if m == FaceRig.Mode.TALK or (m == FaceRig.Mode.LAUGH and cur != FaceRig.Mode.TALK) or cur == FaceRig.Mode.CLOSED:
			mode[s.hero] = m
		if m != FaceRig.Mode.SMILE and s.t0 > latest:
			latest = s.t0
			speaker = s.hero
			speaker_line = i
	for hero_id in actors:
		var a: DioramaActor = actors[hero_id]
		a.face.set_mode(mode.get(hero_id, FaceRig.Mode.CLOSED), time)
	if speaker_line != _speaker_line:
		_speaker_line = speaker_line
		_speaker = speaker
		if speaker != "" and data.speech[speaker_line].mode == HomeDioramaData.SPEECH_TALK:
			turn_started.emit(speaker, speaker_line)
	var focus: Vector3 = data.look_default
	if _speaker != "":
		focus = (actors[_speaker] as DioramaActor).head_world()
	for hero_id in actors:
		(actors[hero_id] as DioramaActor).set_gaze_goal(data.look_default if hero_id == _speaker or _speaker == "" else focus)

func _update_bystanders() -> void:
	for who in walkers:
		var a: DioramaActor = walkers[who]
		var e: Dictionary = data.bystanders[who]
		if not e.has("from"):
			a.seek_loop(time)
			continue
		var dist: float = (e.to - e.from).length()
		var dur: float = dist / float(e.speed)
		var u: float = time - float(e.t0)
		a.visible = u >= 0.0 and u <= dur
		if not a.visible:
			continue
		var dir: Vector3 = (e.to - e.from) / dist
		a.position = e.from + dir * float(e.speed) * u
		a.rotation.y = atan2(dir.x, dir.z)
		a.seek_clip(u)

func _update_pass() -> void:
	var dist: float = (data.pass_to - data.pass_from).length()
	var dur: float = dist / data.pass_speed
	var u: float = time - data.pass_t0
	_pass_audio(u)
	pass_vehicle.visible = u >= 0.0 and u <= dur
	if not pass_vehicle.visible:
		return
	var dir: Vector3 = (data.pass_to - data.pass_from) / dist
	var ph := TAU * data.pass_bob_hz * u
	pass_vehicle.position = data.pass_from + dir * data.pass_speed * u + Vector3(0, data.pass_bob_amp * sin(ph), 0)
	pass_vehicle.rotation.x = deg_to_rad(data.pass_pitch_deg) * sin(ph * 0.5)

## Engine at the start of the pass, horn at `pass_horn_u`; only on a live (non-manual) diorama.
func _pass_audio(u: float) -> void:
	if audio_enabled and not manual:
		if _pass_engine and _pass_u_prev < 0.0 and u >= 0.0:
			_pass_engine.play()
		if _pass_horn and _pass_u_prev >= 0.0 and _pass_u_prev < data.pass_horn_u and u >= data.pass_horn_u:
			_pass_horn.play()
	_pass_u_prev = u

## Where the tricycle is along its road at loop time (0 before it enters, 1 after it leaves).
func pass_progress() -> float:
	var dur: float = (data.pass_to - data.pass_from).length() / data.pass_speed
	return clampf((time - data.pass_t0) / dur, 0.0, 1.0)
