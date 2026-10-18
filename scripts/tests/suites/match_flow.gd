extends RefCounted

## scenes/match.tscn end to end: the real map, a quick 5v5 lineup from Session, every hero
## driven by a BotBrain (the --autoplay setup), ~600 physics frames with the real physics tick.

func run(t: TestCtx) -> void:
	var session := t.tree.root.get_node_or_null("Session")
	if not t.check(session != null, "Session autoload must exist"):
		return
	var saved_lineup: Array = session.lineup
	var saved_settings: Dictionary = session.settings.duplicate()
	session.lineup = session.quick_lineup("tutoy")
	session.local_slot = 0
	session.settings = MatchHost.default_settings()
	session.settings["seed"] = 77
	session.settings["base_mode"] = 1
	session.settings["skip_intro"] = true

	var scene := (load("res://scenes/match.tscn") as PackedScene).instantiate()
	t.tree.root.add_child(scene)
	await t.physics_frames(1)
	var host: MatchHost = scene.host
	if not t.check(host != null, "the match scene builds a MatchHost"):
		scene.queue_free()
		session.lineup = saved_lineup
		session.settings = saved_settings
		return
	t.check(host.heroes.size() == 10, "5v5: ten heroes (got %d)" % host.heroes.size())
	t.check(scene.local_hero != null and scene.local_hero.slot == 0 and scene.local_hero.data.id == "tutoy", "the local hero is the picked one in slot 0")
	t.check(scene.hud != null and scene.camera != null and scene.view != null and scene.player_input != null, "HUD, camera, view and player input exist")
	t.check(host.layout.site_count(RB.DILAW) >= 1 and host.layout.site_count(RB.LILA) >= 1, "the Barangay Court has a base per side")
	t.check(host.base_system.site_number == 1, "v0.2: the base is fixed (site 1)")
	t.check(host.layout.line_length(RB.DILAW) > 10.0 and host.layout.line_length(RB.LILA) > 10.0, "the Barangay Court has a jail line at each end (%.1f / %.1f m)" % [host.layout.line_length(RB.DILAW), host.layout.line_length(RB.LILA)])
	# all ten heroes bot-driven, as with --autoplay
	var brains: Array[BotBrain] = []
	for h in host.heroes:
		var brain := BotBrain.new()
		scene.add_child(brain)
		brain.setup(h, host, 1)
		host.input_sources[h.slot] = brain
		brains.append(brain)
	var start_pos: Dictionary = {}
	for h in host.heroes:
		start_pos[h.slot] = h.global_position
	var events: Array = []
	host.event.connect(func(kind: String, _d: Dictionary): events.append(kind))
	await t.physics_frames(600)
	t.check(host.tick >= 590, "the host ticks with the physics frames (tick %d)" % host.tick)
	t.check(host.round_flow.round_number >= 1, "a round is under way")
	var moved := 0
	for h in host.heroes:
		if RB.flat_dist(h.global_position, start_pos[h.slot]) > 1.0:
			moved += 1
		var inside: bool = host.layout.bounds.grow(0.5).has_point(Vector2(h.global_position.x, h.global_position.z))
		t.check(inside and h.global_position.y > -1.8 and h.global_position.y < 6.0, "%s stayed in the play area: court, stands or the street flank (%s)" % [h.name, h.global_position])
	t.check(moved >= 6, "bots move once the round is live (%d of 10 moved > 1 m)" % moved)
	t.check("kaboom" in events, "KABOOM fired during the run")
	t.check(host.round_live() or host.round_flow.phase == RoundFlow.Phase.ROUND_OVER, "the round is live or just ended")
	# Kurt's distance focus: the ink pass stays sharp around the local hero, softer further out
	var ink: ShaderMaterial = scene.camera.ink
	if t.check(ink != null, "the camera drives the illustrated-edges pass"):
		var fw: Vector3 = ink.get_shader_parameter("focus_world")
		t.check(RB.flat_dist(fw, scene.local_hero.global_position) < 1.5, "the focus follows the local hero (%s vs %s)" % [fw, scene.local_hero.global_position])
		t.check(float(ink.get_shader_parameter("distance_focus_enabled")) > 0.99, "the distance blur is on outside the intro flyover")
		var clear_r := _ink_param(ink, "clear_radius")
		var blur_r := _ink_param(ink, "blur_radius")
		t.check(clear_r >= 3.0 and blur_r > clear_r + 4.0, "a sharp circle round the hero, blurring further out (%.1f -> %.1f m)" % [clear_r, blur_r])
	t.ok("match scene ran 600 physics frames with bots, %d events" % events.size())

	scene.queue_free()
	await t.frames(2)
	session.lineup = saved_lineup
	session.settings = saved_settings
	await _training(t)


## A float uniform as the pass uses it: the material's value, else the shader's declared default
## (unset uniforms read back null, and headless has no renderer to ask for defaults).
func _ink_param(ink: ShaderMaterial, uniform: String) -> float:
	var v: Variant = ink.get_shader_parameter(uniform)
	if v != null:
		return float(v)
	var re := RegEx.create_from_string("uniform\\s+float\\s+%s\\s*=\\s*([0-9.]+)" % uniform)
	var m := re.search(ink.shader.code)
	return float(m.get_string(1)) if m else -1.0

func _training(t: TestCtx) -> void:
	var session := t.tree.root.get_node("Session")
	var saved := {"settings": session.settings.duplicate(true), "mode": session.mode, "lineup": session.lineup, "local_slot": session.local_slot, "results": session.last_results}
	for map_id in ["barangay_court", "construction_site"]:
		session.prepare_training("nene", map_id, false)
		var scene = load("res://scenes/match.tscn").instantiate()
		t.tree.root.add_child(scene)
		var host: MatchHost = scene.host
		host.manual_step = true
		await t.physics_frames(2)
		t.check(host.training != null and scene.bots.is_empty() and host.heroes.size() == 4, "%s training creates stationary dummies and no bot brains" % map_id)
		t.check(host.round_live() and scene.tutorial == null, "free training starts immediately without guided lessons")
		host.round_flow.timer_ticks = 2
		t.steps(host, 5)
		t.check(host.round_flow.timer_ticks == 2 and host.round_live(), "training clock never expires")
		var local: Hero = scene.local_hero
		var dummy: Hero = host.heroes[1]
		for h in host.heroes:
			t.check(host.layout.bounds.has_point(Vector2(h.global_position.x, h.global_position.z)), "training actor starts inside the map bounds")
			var ground := host.ray_hit(h.global_position + Vector3.UP, h.global_position - Vector3.UP * 2.0, RB.L_WORLD | RB.L_VAULTABLE)
			t.check(not ground.is_empty() and absf(ground.position.y - h.global_position.y) < 0.25, "training actors start on supported clear floor")
		var marker := scene.map_root.get_node("Gameplay/TrainingSpawn") as Node3D
		t.check(RB.flat_dist(local.global_position, marker.global_position) < 0.1, "training starts at the authored clear testing area")
		for target in host.heroes.slice(1):
			t.check(host.los_clear(local.global_position, target.global_position, RB.L_WORLD | RB.L_VAULTABLE), "training targets are reachable across clear ground")
		var original: Vector3 = host.training.starts[local.slot]
		local.teleport(dummy.global_position - Vector3.RIGHT * 1.2)
		var input := ScriptedInput.new()
		host.input_sources[local.slot] = input
		input.aim_at(local, dummy.global_position)
		input.press(local, RB.BTN_TAG)
		t.steps(host, RB.ticks(host.tuning.tag_windup) + 1)
		t.check(dummy.state == Hero.State.TAGGED, "training uses the real tagging system")
		t.steps(host, RB.ticks(host.tuning.training_reset_delay))
		t.check(dummy.is_free() and host.jail_system.chain(RB.DILAW).is_empty() and local.global_position.distance_to(original) < 0.2, "tagged training targets and positions reset after the configured delay")
		t.check(t.near(local.skills[0].cooldown, local.data.skill1_cooldown * host.tuning.training_cooldown_scale), "training uses half skill cooldowns")
		local.skills[0].cd_ticks = 100
		scene.view.arena._crumble.assign([1.0, 1.0])
		host.training.reset_requested = true
		t.check(local.skills[0].cd_ticks == 100, "training reset request waits for the host tick")
		t.steps(host, 1)
		t.check(local.skills[0].cd_ticks == 0 and host.objects.is_empty(), "manual training reset clears cooldowns and skill effects")
		t.check(scene.view.arena._crumble[0] < 0.0 and scene.view.arena._crumble[1] < 0.0, "training resets rebuild captured base visuals")
		host.emit_event("capture", {"hero": local, "team": local.team})
		t.steps(host, RB.ticks(host.tuning.training_reset_delay))
		t.check(host.round_flow.score == [0, 0] and host.round_live() and session.last_results.is_empty(), "training captures never score or write match results")
		scene.hud.touch.menu_button.pressed.emit()
		t.check(host.paused and not scene.player_input.enabled, "training supports offline pause")
		scene.queue_free()
		await t.frames(2)
	session.prepare_training("tutoy", "barangay_court", true)
	var moving = load("res://scenes/match.tscn").instantiate()
	t.tree.root.add_child(moving)
	t.check(moving.bots.size() == 3 and moving.host.training != null, "active-bot training uses three normal BotBrains")
	moving.queue_free()
	await t.frames(2)
	session.settings = saved.settings
	session.mode = saved.mode
	session.lineup = saved.lineup
	session.local_slot = saved.local_slot
	session.last_results = saved.results
