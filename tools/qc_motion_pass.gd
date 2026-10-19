extends SceneTree

## Deterministic host-tick review of the real maps; writes only renders/motion_game/.
var scene: Node3D
var host: MatchHost
var hero: Hero
var input: ScriptedInput
var camera: Camera3D
var out := "res://renders/motion_game"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):only = argument.trim_prefix("--only=")
	for id in HeroData.ORDER:
		if only != "" and id not in only.split(","):continue
		root.get_node("Session").prepare_training(id, "barangay_court")
		scene = load("res://scenes/match.tscn").instantiate()
		root.add_child(scene)
		host = scene.host
		host.manual_step = true
		hero = scene.local_hero
		input = ScriptedInput.new()
		for h in host.heroes:
			host.input_sources[h.slot] = input
			if h != hero:
				h.teleport(hero.global_position + Vector3(9 + h.slot, 0, 9))
		scene.hud.root.visible = false
		camera = Camera3D.new()
		scene.add_child(camera)
		camera.current = true
		camera.fov = 32
		input.aim_at(hero, hero.global_position + Vector3.BACK * 6)
		await _steps(15)
		await _capture(id + "_idle")
		input.move(hero, Vector2(0, 0.35))
		await _steps(20)
		await _capture(id + "_walk")
		input.move(hero, Vector2.DOWN)
		await _steps(18)
		await _capture(id + "_run")
		input.move(hero, Vector2.ZERO)
		await _steps(12)
		input.press(hero, RB.BTN_TAG)
		var windup_ticks := RB.ticks(host.tuning.tag_windup)
		var coil_sample := ceili(windup_ticks * 0.65)
		await _steps(coil_sample)
		await _capture(id + "_windup")
		await _steps(windup_ticks + 1 - coil_sample)
		await _capture(id + "_miss_contact")
		await _steps(8)
		await _capture(id + "_stumble")
		await _steps(35)
		if id == "nene":
			input.press(hero, RB.BTN_SKILL1)
			await _steps(8)
			await _capture("nene_shout")
			await _steps(40)
			input.move(hero, Vector2.DOWN)
			input.press(hero, RB.BTN_SKILL2)
			await _steps(10)
			await _capture("nene_moving_ward")
		elif id == "nathan":
			input.press(hero, RB.BTN_SKILL2)
			await _steps(7)
			await _capture("nathan_bag_pickup")
			await _steps(6)
			await _capture("nathan_throw_prepare")
			await _steps(6)
			await _capture("nathan_release")
		elif id == "inday":
			input.press(hero, RB.BTN_SKILL1)
			await _steps(15)
			await _capture("inday_lane_25")
			await _steps(15)
			await _capture("inday_lane_50")
			await _steps(30)
			await _capture("inday_lane_100")
			input.press(hero, RB.BTN_SKILL2)
			await _steps(8)
			await _capture("inday_hila_back", true)
			await _steps(35)
			await _capture("inday_hair_back", true)
		elif id == "jm":
			await _capture("jm_towel_back", true)
		scene.queue_free()
		await process_frame
	for map_id in ["barangay_court", "construction_site"]:
		root.get_node("Session").prepare_training("nene", map_id)
		scene = load("res://scenes/match.tscn").instantiate()
		root.add_child(scene)
		for i in range(12):await process_frame
		await _image(map_id + "_style")
		scene.queue_free()
		await process_frame
	quit()

func _steps(count: int) -> void:
	for i in range(count):
		host.step()
		await process_frame

func _capture(label: String, back := false) -> void:
	var front := hero.visual.model.global_basis.z.normalized()
	var right := hero.visual.model.global_basis.x.normalized()
	camera.global_position = hero.global_position + front * (-3.8 if back else 3.8) + right * 1.3 + Vector3.UP * 1.9
	camera.look_at(hero.global_position + Vector3.UP * 1.05)
	await _image(label)

func _image(label: String) -> void:
	for i in range(2):await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out.path_join(label + ".png")))
	print("MOTION_REVIEW ", label, " save=", error)
