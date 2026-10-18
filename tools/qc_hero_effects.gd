extends SceneTree

## Repeatable real-map presentation review; no scene/resource writes, only renders/hero_fx.
## Run windowed: godot --path . --windowed --resolution 1280x720 -s tools/qc_hero_effects.gd
var scene: Node3D
var input: ScriptedInput
var output_dir := "res://renders/hero_fx"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
		elif argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	for id in HeroData.ORDER:
		if only != "" and id not in only.split(","):
			continue
		var session := root.get_node("Session")
		session.prepare_training(id, "barangay_court")
		scene = load("res://scenes/match.tscn").instantiate()
		root.add_child(scene)
		var host: MatchHost = scene.host
		host.manual_step = true
		input = ScriptedInput.new()
		for hero in host.heroes:
			host.input_sources[hero.slot] = input
		var me: Hero = scene.local_hero
		var origin := me.global_position
		var dir := me.facing
		for slot in range(2):
			host.training.reset()
			for i in range(host.heroes.size()):
				if i > 1:
					host.heroes[i].teleport(origin - dir * (8.0 + i))
			var target: Hero = host.heroes[1]
			target.team = me.team if id == "inday" else RB.other_team(me.team)
			target.teleport(origin + dir * (6.0 if id == "inday" and slot == 1 else (4.0 if id == "inday" else 2.5)))
			input.aim_at(me, origin + dir * 4.0)
			for i in range(12):
				host.step()
				await process_frame
			input.press(me, RB.BTN_SKILL1 if slot == 0 else RB.BTN_SKILL2)
			var ticks := 8
			if id == "nathan": ticks = 28 if slot == 0 else 34
			if id == "jm" and slot == 0: ticks = 38
			for i in range(ticks):
				host.step()
				await process_frame
				if id == "nathan" and slot == 1 and i == 8:
					await _capture("nathan_packet")
			scene.hud.root.visible = false
			await _capture("%s_s%d" % [id, slot + 1])
			if id == "inday" and slot == 1:
				print("HILA rendered hand distance ", me.visual.hand_position(0).distance_to(me.visual.hila_visual_target()), " modifier error ", me.visual.elastic_arm.get_meta("target_error", -1))
				print("HILA active ", me.visual.hila_pose_active(), " target ", me.visual.hila_visual_target(), " cached hand ", me.visual.elastic_arm.get_meta("hand_world", Vector3.ZERO))
			if id == "nathan" and slot == 1:
				for object in host.objects:
					if object is UboCloud:
						me.teleport(object.global_position)
				await process_frame
				await _capture("nathan_owner_inside")
				scene.hud.local = target
				scene.view.local = target
				scene.hud.root.visible = true
				await process_frame
				await _capture("nathan_enemy_blind")
		if id == "jm":
			host.training.reset()
			var target: Hero = host.heroes[1]
			target.teleport(origin + dir * 1.3)
			var preparation := PlayerInput.new()
			host.add_child(preparation)
			host.input_sources[me.slot] = preparation
			preparation.set_touch_move(Vector2(-dir.x, -dir.z))
			preparation.begin_tag_aim()
			for i in range(20):
				host.step()
				await process_frame
			await _capture("jm_prepared_walk")
			target.teleport(me.global_position + dir * 1.3)
			preparation.set_touch_move(Vector2.ZERO)
			preparation.finish_tag_aim()
			for i in range(18):
				host.step()
				await process_frame
			await _capture("jm_towel_tag")
		scene.queue_free()
		await process_frame
	quit()

func _capture(label: String) -> void:
	for i in range(3):
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(output_dir.path_join("%s.png" % label)))
	if error != OK:
		push_error("Skill review screenshot failed: " + label)
	print("HERO FX ", label)
