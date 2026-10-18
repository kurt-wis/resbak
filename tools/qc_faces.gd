extends SceneTree

## Face-card QC: renders every hero's head close-up (front and 3/4) with each mouth frame and
## each eyelid frame, lit and toon-shaded like the Home diorama, to renders/home_diorama/faces/.
## Needs a real renderer (not --headless):
##   & $env:GODOT --path . --windowed --resolution 960x540 -s tools/qc_faces.gd [-- --hero=nene]
## Look at the sheets for card edges, floating cards and z-fighting.

const OUT := "res://renders/home_diorama/faces/"
const CELL := 320
const FOV := 26.0
const DIST := 0.85 ## metres from the face centre, at model scale 1
const YAWS := [0.0, 35.0] ## front, then 3/4
const BASE_CLIP := {"tutoy": "Menu_StandIdle", "inday": "Menu_StandIdle"}

var _data: HomeDioramaData
var _pose := ""

func _initialize() -> void:
	_data = HomeDioramaData.load_data()
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero="):
			only = a.substr(7)
		elif a.begins_with("--pose="): ## any clip name, to check the cards in another pose
			_pose = a.substr(7)
	var failed := 0
	for id in HeroData.ORDER:
		if only != "" and id != only:
			continue
		if not await _hero(id):
			failed += 1
	print("QC_FACES done, failed=%d" % failed)
	quit(failed)

func _hero(id: String) -> bool:
	var hd := HeroData.load_hero(id)
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("56627a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8fb4d9")
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 150, 0)
	sun.light_color = Color("ffc27a")
	sun.light_energy = 1.3
	vp.add_child(sun)
	var model := (load(hd.glb) as PackedScene).instantiate() as Node3D
	vp.add_child(model)
	Portraits._normalise(model, hd.model_height)
	Portraits._toon(model)
	var rig := FaceRig.new()
	if not rig.attach(id, model, _data):
		push_error("QC_FACES %s: FaceRig.attach failed" % id)
		vp.queue_free()
		return false
	var anim: AnimationPlayer = null
	for n in model.find_children("*", "AnimationPlayer", true, false):
		anim = n
		break
	var clip: String = BASE_CLIP.get(id, "Menu_SitIdle")
	if _pose != "":
		clip = _pose
	if anim and anim.has_animation(clip):
		anim.play(clip)
		anim.seek(0.5, true)
		anim.pause()
	var cam := Camera3D.new()
	cam.fov = FOV
	vp.add_child(cam)
	cam.current = true
	await process_frame
	await process_frame
	var centre := Vector3.ZERO
	for card in [rig.mouth, rig.eye_r, rig.eye_l]: ## the cards' vertices carry the position, not the node
		centre += (card as MeshInstance3D).global_transform * (card as MeshInstance3D).get_aabb().get_center()
	centre /= 3.0
	var dist := DIST * model.scale.x
	var frames: Array[Vector2i] = [] ## (mouth frame, lid frame)
	for m in range(_data.mouth_atlas_cols * _data.mouth_atlas_rows):
		frames.append(Vector2i(m, _data.lid_open))
	for l in range(_data.lid_atlas_cols * _data.lid_atlas_rows):
		frames.append(Vector2i(_data.mouth_closed, l))
	var sheet := Image.create(CELL * frames.size(), CELL * YAWS.size(), false, Image.FORMAT_RGBA8)
	for row in range(YAWS.size()):
		var yaw := deg_to_rad(YAWS[row])
		cam.look_at_from_position(centre + Vector3(sin(yaw), 0.05, cos(yaw)).normalized() * dist, centre)
		for col in range(frames.size()):
			rig.set_frames(frames[col].x, frames[col].y)
			for i in range(3):
				await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, row * CELL))
	var path := ProjectSettings.globalize_path(OUT + "%s_faces.png" % id)
	var err := sheet.save_png(path)
	print("QC_FACES %s -> %s (err %d)" % [id, path, err])
	vp.queue_free()
	return err == OK
