extends SceneTree

## Reproducible in-game shoulder cloth / gait / miss review, front and back.
var scene: Node3D
var host: MatchHost
var me: Hero
var input: ScriptedInput
var camera: Camera3D
var output := "res://renders/jm_shoulder_final"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_node("Session").prepare_training("jm", "barangay_court")
	scene = load("res://scenes/match.tscn").instantiate()
	root.add_child(scene)
	host = scene.host
	host.manual_step = true
	me = scene.local_hero
	input = ScriptedInput.new()
	for h in host.heroes:
		host.input_sources[h.slot] = input
		if h != me:
			h.teleport(me.global_position + Vector3(10 + h.slot, 0, 0))
	scene.hud.root.visible = false
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	camera.fov = 32
	me.facing = Vector3.BACK
	input.aim_at(me, me.global_position + Vector3.BACK * 6)
	for i in range(20):
		host.step()
		await process_frame
	await _capture("idle_front", false)
	await _capture("idle_back", true)
	input.move(me, Vector2.DOWN)
	for i in range(15):
		host.step()
		await process_frame
	await _capture("running_front", false)
	await _capture("running_back", true)
	input.move(me, Vector2.ZERO)
	for i in range(12):
		host.step()
		await process_frame
	input.press(me, RB.BTN_SKILL2)
	for i in range(5):
		host.step()
		await process_frame
	input.press(me, RB.BTN_SKILL2)
	host.step()
	for i in range(4):
		host.step()
		await process_frame
	await _capture("miss_dizzy", false)
	print("MISS review ticks ", me.cast_lock_ticks, " clip ", me.visual._desired()[0])
	for i in range(me.cast_lock_ticks + 3):
		host.step()
		await process_frame
	input.press(me, RB.BTN_TAG)
	for i in range(18):
		host.step()
		await process_frame
	await _capture("towel_strike", false)
	quit()

func _capture(label: String, back: bool) -> void:
	var front := me.visual.model.global_basis.z.normalized()
	var right := me.visual.model.global_basis.x.normalized()
	camera.global_position = me.global_position + front * (-3.3 if back else 3.3) + right * 1.3 + Vector3.UP * 1.8
	camera.look_at(me.global_position + Vector3.UP * 0.95)
	for i in range(8):
		await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(label + ".png")))
	print("CARRY REVIEW ", label, " save=", error)
