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
	t.check(host.layout.site_count(RB.DILAW) == 3 and host.layout.site_count(RB.LILA) == 3, "the Barangay Court has three base sites per side")
	t.check(host.base_system.site_number == 1, "fixed base site 1 from the settings")
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
		t.check(h.global_position.y > -1.0 and h.global_position.y < 6.0, "%s stayed on the court (y %.2f)" % [h.name, h.global_position.y])
	t.check(moved >= 6, "bots move once the round is live (%d of 10 moved > 1 m)" % moved)
	t.check("kaboom" in events, "KABOOM fired during the run")
	t.check(host.round_live() or host.round_flow.phase == RoundFlow.Phase.ROUND_OVER, "the round is live or just ended")
	t.ok("match scene ran 600 physics frames with bots, %d events" % events.size())

	scene.queue_free()
	await t.frames(2)
	session.lineup = saved_lineup
	session.settings = saved_settings
